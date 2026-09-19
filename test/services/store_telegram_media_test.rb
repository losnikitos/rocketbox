# frozen_string_literal: true

require "test_helper"
require "stringio"

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
    assert_equal 0, LibraryMedia.count
  end

  test "attaches media to user matching telegram_user_id" do
    user = users(:lazaro_nixon)
    user.update!(telegram_user_id: 90504516)

    media = store_photo!(from_id: 90504516, unique_id: "linked-photo")

    assert_equal user.id, media.user_id
    assert media.file.attached?
  end

  test "leaves user_id nil when no matching telegram_user_id" do
    media = store_photo!(from_id: 111222333, unique_id: "orphan-photo")

    assert_nil media.user_id
  end

  private

    def store_photo!(from_id:, unique_id:)
      update = {
        "update_id" => 1,
        "message" => {
          "message_id" => 10,
          "date" => Time.now.to_i,
          "chat" => { "id" => from_id, "type" => "private" },
          "from" => { "id" => from_id, "is_bot" => false, "first_name" => "Test" },
          "photo" => [
            {
              "file_id" => "file-#{unique_id}",
              "file_unique_id" => unique_id,
              "width" => 800,
              "height" => 600,
              "file_size" => 12_000
            }
          ]
        }
      }

      file = Struct.new(:file_path).new("photos/#{unique_id}.jpg")
      api = Object.new
      api.define_singleton_method(:get_file) { |**_| file }
      api.define_singleton_method(:set_message_reaction) { |**_| true }
      client = Object.new
      client.define_singleton_method(:api) { api }

      original_client = TelegramBot.method(:client)
      original_token = TelegramBot.method(:token)
      original_open = URI.method(:open)

      begin
        TelegramBot.define_singleton_method(:client) { client }
        TelegramBot.define_singleton_method(:token) { "test-token" }
        URI.define_singleton_method(:open) do |*_args|
          StringIO.new("fake-image-bytes").tap do |io|
            io.define_singleton_method(:content_type) { "image/jpeg" }
          end
        end

        StoreTelegramMedia.call(update)
      ensure
        TelegramBot.define_singleton_method(:client, original_client)
        TelegramBot.define_singleton_method(:token, original_token)
        URI.define_singleton_method(:open, original_open)
      end
    end
end
