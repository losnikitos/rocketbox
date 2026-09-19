# frozen_string_literal: true

require "test_helper"

class StoreTelegramMediaTest < ActiveSupport::TestCase
  test "ignores messages without media" do
    update = {
      "update_id" => 1,
      "message" => {
        "message_id" => 1,
        "date" => Time.now.to_i,
        "chat" => { "id" => 1, "type" => "private" },
        "text" => "hello"
      }
    }

    assert_nil StoreTelegramMedia.call(update)
    assert_equal 0, TelegramUpload.count
  end
end
