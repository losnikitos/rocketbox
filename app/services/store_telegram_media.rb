# frozen_string_literal: true

require "open-uri"
require "telegram/bot"

class StoreTelegramMedia
  MEDIA_ATTRS = %i[document video audio voice video_note animation sticker].freeze

  def self.call(update)
    new(update).call
  end

  def self.media?(message)
    return false if message.blank?

    message.photo.present? || MEDIA_ATTRS.any? { |attr| message.public_send(attr).present? }
  end

  def initialize(update)
    @update = update.is_a?(Hash) ? Telegram::Bot::Types::Update.new(update) : update
  end

  def call
    message = @update.message || @update.edited_message
    return if message.blank?

    tg_media, kind = extract_media(message)
    return if tg_media.blank?

    existing = LibraryMedia.find_by(telegram_file_unique_id: tg_media.file_unique_id)
    if existing
      attach_to_incoming_message!(message.message_id, existing.file.blob) if existing.file.attached?
      return existing
    end

    file = TelegramBot.client.api.get_file(file_id: tg_media.file_id)
    media = download_and_store!(message:, tg_media:, kind:, file_path: file.file_path)
    react_ok(message)
    media
  end

  private

    def extract_media(message)
      if message.photo.present?
        return message.photo.max_by { |p| p.file_size.to_i }, "photo"
      end

      MEDIA_ATTRS.each do |attr|
        tg_media = message.public_send(attr)
        return tg_media, attr.to_s if tg_media.present?
      end

      [ nil, nil ]
    end

    def download_and_store!(message:, tg_media:, kind:, file_path:)
      url = "https://api.telegram.org/file/bot#{TelegramBot.token}/#{file_path}"
      io = URI.open(url)
      filename = File.basename(file_path.presence || "telegram-#{tg_media.file_unique_id}")

      from_id = message.from&.id
      media = LibraryMedia.create!(
        telegram_file_id: tg_media.file_id,
        telegram_file_unique_id: tg_media.file_unique_id,
        chat_id: message.chat&.id,
        from_id: from_id,
        kind: kind,
        user: User.find_by(telegram_user_id: from_id)
      )

      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: filename,
        content_type: io.content_type.presence || "application/octet-stream"
      )
      media.file.attach(blob)
      attach_to_incoming_message!(message.message_id, blob)
      media
    ensure
      io&.close
    end

    def attach_to_incoming_message!(external_id, blob)
      IncomingMessage.find_by(channel: "telegram", external_id: external_id.to_s.presence)
        &.attachments&.attach(blob)
    end

    def react_ok(message)
      TelegramBot.client.api.set_message_reaction(
        chat_id: message.chat.id,
        message_id: message.message_id,
        reaction: [ { type: "emoji", emoji: "👍" } ]
      )
    rescue StandardError => e
      Rails.logger.warn("Telegram reaction failed: #{e.class}: #{e.message}")
    end
end
