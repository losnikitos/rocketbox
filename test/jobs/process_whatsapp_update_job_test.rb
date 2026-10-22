# frozen_string_literal: true

require "test_helper"

class ProcessWhatsappUpdateJobTest < ActiveJob::TestCase
  test "text from a new number creates a user and starts onboarding" do
    sent = capture_texts do
      assert_difference -> { User.count }, 1 do
        ProcessWhatsappUpdateJob.perform_now(text_payload("Hey"))
      end
    end

    user = User.find_by!(whatsapp_phone: "15551234567")
    assert_nil user.whatsapp_pending_question
    assert_equal [ "What's the business called?" ], sent
  end

  test "non-text from a new number does not create a user" do
    payload = {
      "entry" => [ {
        "changes" => [ {
          "field" => "messages",
          "value" => { "messages" => [ { "from" => "15551234567", "id" => "wamid.loc", "type" => "location" } ] }
        } ]
      } ]
    }

    assert_no_difference -> { User.count } do
      ProcessWhatsappUpdateJob.perform_now(payload)
    end
  end

  test "START_<code> links the phone to the existing account, once" do
    user = users(:lazaro_nixon)
    user.regenerate_whatsapp_link_code
    code = user.whatsapp_link_code

    sent = capture_texts do
      assert_no_difference -> { User.count } do
        ProcessWhatsappUpdateJob.perform_now(text_payload("START_#{code}"))
      end
    end

    user.reload
    assert_equal "15551234567", user.whatsapp_phone
    assert_not_equal code, user.whatsapp_link_code
    assert_nil user.whatsapp_pending_question
    assert_equal [ "WhatsApp connected.", "What's the business called?" ], sent

    sent = capture_texts { ProcessWhatsappUpdateJob.perform_now(text_payload("START_#{code}")) }
    assert_match(/expired/, sent.sole)
  end

  test "START_<code> refuses a phone that belongs to another account" do
    other = User.create!(whatsapp_phone: "15551234567")
    user = users(:lazaro_nixon)
    user.regenerate_whatsapp_link_code

    sent = capture_texts { ProcessWhatsappUpdateJob.perform_now(text_payload("START_#{user.whatsapp_link_code}")) }

    assert_nil user.reload.whatsapp_phone
    assert_equal "15551234567", other.reload.whatsapp_phone
    assert_match(/another Rocketbox account/, sent.sole)
  end

  test "START_<code> refuses a second phone for an already connected account" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "447000000000")
    user.regenerate_whatsapp_link_code

    sent = capture_texts { ProcessWhatsappUpdateJob.perform_now(text_payload("START_#{user.whatsapp_link_code}")) }

    assert_equal "447000000000", user.reload.whatsapp_phone
    assert_match(/already has a WhatsApp number/, sent.sole)
  end

  test "unknown START_<code> creates no account" do
    sent = nil
    assert_no_difference -> { User.count } do
      sent = capture_texts { ProcessWhatsappUpdateJob.perform_now(text_payload("START_nope")) }
    end
    assert_match(/expired/, sent.sole)
  end

  private

    def text_payload(body)
      {
        "entry" => [ {
          "changes" => [ {
            "field" => "messages",
            "value" => {
              "metadata" => { "phone_number_id" => "1369590492903246" },
              "messages" => [ { "from" => "15551234567", "id" => "wamid.text", "type" => "text", "text" => { "body" => body } } ]
            }
          } ]
        } ]
      }
    end

    def capture_texts
      sent = []
      original = WhatsappCloud.method(:send_text)
      original_reply = RocketboxAgent.method(:reply)
      WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }
      RocketboxAgent.define_singleton_method(:reply) { |*| Struct.new(:content).new("What's the business called?") }
      yield
      sent
    ensure
      WhatsappCloud.define_singleton_method(:send_text, original)
      RocketboxAgent.define_singleton_method(:reply, original_reply)
    end
end
