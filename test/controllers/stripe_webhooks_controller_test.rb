# frozen_string_literal: true

require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    host! "www.example.com"
  end

  test "rejects when webhook secret missing" do
    stub_stripe_webhook_secret(nil) do
      post stripe_webhook_path, params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :unprocessable_entity
    end
  end

  test "accepts signed payload and processes job" do
    user = users(:lazaro_nixon)
    payload = {
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "mode" => "subscription",
          "subscription" => "sub_hook",
          "client_reference_id" => user.id.to_s,
          "customer" => "cus_hook"
        }
      }
    }.to_json

    stripe_sub = Stripe::Subscription.construct_from(
      id: "sub_hook",
      object: "subscription",
      customer: "cus_hook",
      status: "active",
      current_period_end: 1.month.from_now.to_i,
      metadata: { "user_id" => user.id.to_s }
    )

    stub_stripe_webhook_secret("whsec_test_123") do
      stub_stripe_webhook_construct_event do
        stub_stripe_subscription_retrieve(stripe_sub) do
          perform_enqueued_jobs do
            post stripe_webhook_path,
              params: payload,
              headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "v1,test" }
          end
        end
      end
    end

    assert_response :ok
    assert user.subscription.reload.active?
  end
end
