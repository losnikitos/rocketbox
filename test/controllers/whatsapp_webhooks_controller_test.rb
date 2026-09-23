# frozen_string_literal: true

require "test_helper"

class WhatsappWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "verifies webhook challenge when token matches" do
    original = WhatsappCloud.method(:webhook_verify_token)
    WhatsappCloud.define_singleton_method(:webhook_verify_token) { "verify-me" }

    get whatsapp_webhook_url, params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "verify-me",
      "hub.challenge" => "challenge-token"
    }

    assert_response :success
    assert_equal "challenge-token", response.body
  ensure
    WhatsappCloud.define_singleton_method(:webhook_verify_token, original)
  end

  test "rejects webhook challenge when token mismatches" do
    original = WhatsappCloud.method(:webhook_verify_token)
    WhatsappCloud.define_singleton_method(:webhook_verify_token) { "verify-me" }

    get whatsapp_webhook_url, params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "wrong",
      "hub.challenge" => "challenge-token"
    }

    assert_response :forbidden
  ensure
    WhatsappCloud.define_singleton_method(:webhook_verify_token, original)
  end

  test "rejects post with invalid signature when app_secret is set" do
    original_secret = WhatsappCloud.method(:app_secret)
    WhatsappCloud.define_singleton_method(:app_secret) { "app-secret" }

    post whatsapp_webhook_url,
      params: { object: "whatsapp_business_account" }.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature-256" => "sha256=deadbeef"
      }

    assert_response :unauthorized
  ensure
    WhatsappCloud.define_singleton_method(:app_secret, original_secret)
  end

  test "enqueues job for signed post" do
    secret = "app-secret"
    body = { "object" => "whatsapp_business_account", "entry" => [] }.to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"

    original_secret = WhatsappCloud.method(:app_secret)
    WhatsappCloud.define_singleton_method(:app_secret) { secret }

    assert_enqueued_with(job: ProcessWhatsappUpdateJob) do
      post whatsapp_webhook_url,
        params: body,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Hub-Signature-256" => signature
        }
    end

    assert_response :ok
  ensure
    WhatsappCloud.define_singleton_method(:app_secret, original_secret)
  end
end
