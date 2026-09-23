# frozen_string_literal: true

class StoreWhatsappMedia
  MEDIA_TYPES = {
    "image" => "photo",
    "video" => "video",
    "audio" => "audio",
    "document" => "document",
    "sticker" => "sticker"
  }.freeze

  def self.call(payload)
    new(payload).call
  end

  def self.media?(message)
    message.is_a?(Hash) && MEDIA_TYPES.key?(message["type"].to_s)
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    last = nil
    each_message do |message|
      next unless self.class.media?(message)

      last = store_message!(message)
    end
    last
  end

  private

    def each_message
      Array(@payload.dig("entry")).each do |entry|
        Array(entry["changes"]).each do |change|
          next unless change["field"] == "messages"

          Array(change.dig("value", "messages")).each { |message| yield message }
        end
      end
    end

    def store_message!(message)
      type = message["type"].to_s
      kind = MEDIA_TYPES.fetch(type)
      media_payload = message[type]
      media_id = media_payload.is_a?(Hash) ? media_payload["id"].presence : nil
      return if media_id.blank?

      existing = LibraryMedia.find_by(whatsapp_media_id: media_id)
      return existing if existing

      from = message["from"].to_s
      io = nil
      io, mime_type, = WhatsappCloud.download_media(media_id)
      filename = filename_for(media_payload, media_id, mime_type)

      media = LibraryMedia.create!(
        whatsapp_media_id: media_id,
        whatsapp_from: from.presence,
        kind: kind,
        user: User.find_by(whatsapp_phone: from.presence)
      )

      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: filename,
        content_type: mime_type
      )
      media.file.attach(blob)
      react_ok(message)
      media
    ensure
      io&.close if defined?(io)
    end

    def filename_for(media_payload, media_id, mime_type)
      name = media_payload.is_a?(Hash) ? media_payload["filename"].presence : nil
      return name if name.present?

      ext = {
        "image/jpeg" => "jpg",
        "image/png" => "png",
        "image/webp" => "webp",
        "video/mp4" => "mp4",
        "audio/ogg" => "ogg",
        "audio/mpeg" => "mp3",
        "application/pdf" => "pdf"
      }[mime_type] || "bin"
      "whatsapp-#{media_id}.#{ext}"
    end

    def react_ok(message)
      WhatsappCloud.react(to: message["from"], message_id: message["id"])
    rescue StandardError => e
      Rails.logger.warn("WhatsApp reaction failed: #{e.class}: #{e.message}")
    end
end
