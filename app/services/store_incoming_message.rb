# frozen_string_literal: true

class StoreIncomingMessage
  TELEGRAM_MEDIA_ATTRS = %i[document video audio voice video_note animation sticker].freeze

  def self.telegram(message)
    new.telegram(message)
  end

  def self.whatsapp(message)
    new.whatsapp(message)
  end

  def telegram(message)
    return if message.blank?

    from_id = message.from&.id
    IncomingMessage.create!(
      channel: "telegram",
      external_id: message.message_id&.to_s,
      sender: from_id&.to_s,
      chat_id: message.chat&.id&.to_s,
      kind: telegram_kind(message),
      body: message.text.presence || message.caption.presence,
      payload: telegram_payload(message),
      user: User.find_by(telegram_user_id: from_id)
    )
  rescue => e
    Rails.logger.error("StoreIncomingMessage.telegram failed: #{e.class}: #{e.message}")
    nil
  end

  def whatsapp(message)
    return unless message.is_a?(Hash)

    from = message["from"].to_s.presence
    IncomingMessage.create!(
      channel: "whatsapp",
      external_id: message["id"].presence,
      sender: from,
      chat_id: nil,
      kind: message["type"].to_s.presence,
      body: whatsapp_body(message),
      payload: message,
      user: User.find_by(whatsapp_phone: from)
    )
  rescue => e
    Rails.logger.error("StoreIncomingMessage.whatsapp failed: #{e.class}: #{e.message}")
    nil
  end

  private

    def telegram_kind(message)
      return "text" if message.text.present?
      return "photo" if message.photo.present?

      TELEGRAM_MEDIA_ATTRS.each do |attr|
        return attr.to_s if message.public_send(attr).present?
      end

      "unknown"
    end

    def telegram_payload(message)
      if message.respond_to?(:to_h)
        message.to_h
      elsif message.respond_to?(:to_hash)
        message.to_hash
      else
        { "message_id" => message.message_id, "text" => message.text, "caption" => message.caption }
      end
    end

    def whatsapp_body(message)
      type = message["type"].to_s
      if type == "text"
        message.dig("text", "body").presence
      else
        media = message[type]
        media.is_a?(Hash) ? media["caption"].presence : nil
      end
    end
end
