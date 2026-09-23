# frozen_string_literal: true

require "test_helper"
require "telegram/bot"

class StoreIncomingMessageTest < ActiveSupport::TestCase
  test "stores telegram text message with channel and body" do
    message = Telegram::Bot::Types::Message.new(
      message_id: 42,
      date: Time.now.to_i,
      chat: { id: 100, type: "private" },
      from: { id: 7, is_bot: false, first_name: "Ada" },
      text: "hello from telegram"
    )

    record = StoreIncomingMessage.telegram(message)

    assert_equal "telegram", record.channel
    assert_equal "42", record.external_id
    assert_equal "7", record.sender
    assert_equal "100", record.chat_id
    assert_equal "text", record.kind
    assert_equal "hello from telegram", record.body
  end

  test "stores whatsapp text message with channel and body" do
    message = {
      "from" => "15551234567",
      "id" => "wamid.test",
      "type" => "text",
      "text" => { "body" => "hello from whatsapp" }
    }

    record = StoreIncomingMessage.whatsapp(message)

    assert_equal "whatsapp", record.channel
    assert_equal "wamid.test", record.external_id
    assert_equal "15551234567", record.sender
    assert_equal "text", record.kind
    assert_equal "hello from whatsapp", record.body
  end
end
