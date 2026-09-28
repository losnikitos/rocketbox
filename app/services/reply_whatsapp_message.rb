# frozen_string_literal: true

class ReplyWhatsappMessage
  INSTRUCTIONS = <<~TEXT.squish
    You are the Rocketbox library assistant.
    Use the list_media tool to answer questions about the user's media library.
    Keep replies short and plain text.
  TEXT

  WHATSAPP_MAX_LENGTH = 4096

  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    each_message do |message, phone_number_id|
      next if StoreWhatsappMedia.media?(message)

      text = message.dig("text", "body").to_s
      next if text.blank?

      from = message["from"].to_s
      next if connect!(phone_number_id, from, text)

      user = User.find_by(whatsapp_phone: from.presence)
      if user && (urls = Link.urls_in(text)).any?
        urls.each { |url| user.links.find_or_create_by!(url:) { it.source = "whatsapp" } }
        react_ok(phone_number_id, from, message["id"])
        next
      end

      chat = Chat.create!
      response = chat
        .with_instructions(INSTRUCTIONS)
        .with_tools(ListMedia.new(user:))
        .ask(text)

      reply = response.content.to_s.truncate(WHATSAPP_MAX_LENGTH)
      WhatsappCloud.send_text(phone_number_id:, to: from, body: reply) if from.present? && reply.present?
    end
  end

  private

    def connect!(phone_number_id, from, text)
      code = text.strip[/\ASTART_(\w+)\z/, 1]
      return false unless code && from.present?

      if (user = User.find_by(whatsapp_connect_code: code))
        User.where(whatsapp_phone: from).where.not(id: user.id).update_all(whatsapp_phone: nil)
        user.update!(whatsapp_phone: from, whatsapp_connect_code: nil)
        LibraryMedia.where(whatsapp_from: from, user_id: nil).update_all(user_id: user.id)
      elsif !User.exists?(whatsapp_phone: from)
        return false
      end

      WhatsappCloud.send_text(phone_number_id:, to: from, body: "Welcome to Rocketbox 👋\nYour account is connected.")
      true
    end

    def react_ok(phone_number_id, from, message_id)
      WhatsappCloud.react(phone_number_id:, to: from, message_id:)
    rescue StandardError => e
      Rails.logger.warn("WhatsApp reaction failed: #{e.class}: #{e.message}")
    end

    def each_message
      Array(@payload.dig("entry")).each do |entry|
        Array(entry["changes"]).each do |change|
          next unless change["field"] == "messages"

          phone_number_id = change.dig("value", "metadata", "phone_number_id")
          Array(change.dig("value", "messages")).each { |message| yield message, phone_number_id }
        end
      end
    end
end
