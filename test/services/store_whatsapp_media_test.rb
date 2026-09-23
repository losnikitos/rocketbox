# frozen_string_literal: true

require "test_helper"
require "stringio"

class StoreWhatsappMediaTest < ActiveSupport::TestCase
  test "ignores messages without media" do
    payload = text_payload(from: "15551234567", body: "hello")

    assert_nil StoreWhatsappMedia.call(payload)
    assert_equal 0, LibraryMedia.count
  end

  test "attaches media to user matching whatsapp_phone" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")

    media = store_image!(from: "15551234567", media_id: "linked-media")

    assert_equal user.id, media.user_id
    assert media.file.attached?
  end

  test "attaches blob to matching IncomingMessage" do
    media = store_image!(from: "15551234567", media_id: "incoming-media")
    incoming = IncomingMessage.find_by!(channel: "whatsapp", external_id: "wamid.incoming-media")

    assert incoming.attachments.attached?
    assert_equal media.file.blob_id, incoming.attachments.first.blob_id
  end

  test "leaves user_id nil when no matching whatsapp_phone" do
    media = store_image!(from: "19998887777", media_id: "orphan-media")

    assert_nil media.user_id
  end

  test "dedupes by whatsapp_media_id" do
    first = store_image!(from: "15551234567", media_id: "same-media")
    second = store_image!(from: "15551234567", media_id: "same-media")

    assert_equal first.id, second.id
    assert_equal 1, LibraryMedia.count
  end

  private

    def text_payload(from:, body:)
      {
        "object" => "whatsapp_business_account",
        "entry" => [ {
          "changes" => [ {
            "field" => "messages",
            "value" => {
              "messages" => [ {
                "from" => from,
                "id" => "wamid.text",
                "timestamp" => Time.now.to_i.to_s,
                "type" => "text",
                "text" => { "body" => body }
              } ]
            }
          } ]
        } ]
      }
    end

    def store_image!(from:, media_id:)
      message = {
        "from" => from,
        "id" => "wamid.#{media_id}",
        "timestamp" => Time.now.to_i.to_s,
        "type" => "image",
        "image" => {
          "id" => media_id,
          "mime_type" => "image/jpeg"
        }
      }
      payload = {
        "object" => "whatsapp_business_account",
        "entry" => [ {
          "changes" => [ {
            "field" => "messages",
            "value" => {
              "messages" => [ message ]
            }
          } ]
        } ]
      }

      StoreIncomingMessage.whatsapp(message)

      original_download = WhatsappCloud.method(:download_media)
      original_react = WhatsappCloud.method(:react)

      begin
        WhatsappCloud.define_singleton_method(:download_media) do |_id|
          [ StringIO.new("fake-image-bytes").tap { |s|
              s.define_singleton_method(:content_type) { "image/jpeg" }
            }, "image/jpeg", { "url" => "https://example.com/#{media_id}" } ]
        end
        WhatsappCloud.define_singleton_method(:react) { |**_| true }

        StoreWhatsappMedia.call(payload)
      ensure
        WhatsappCloud.define_singleton_method(:download_media, original_download)
        WhatsappCloud.define_singleton_method(:react, original_react)
      end
    end
end
