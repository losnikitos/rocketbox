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

      text = message.dig("text", "body").presence || message.dig("interactive", "button_reply", "id").to_s
      next if text.blank?

      from = message["from"].to_s
      user = User.find_by(whatsapp_phone: from.presence)

      if (code = text.strip[WhatsappOnboarding::LINK_PATTERN, 1])
        WhatsappOnboarding.link!(from, code)
        next
      end

      if user && text.strip.casecmp?("start")
        WhatsappOnboarding.ask!(user, "business_card")
        next
      end

      if user && WhatsappOnboarding.answer!(user, text)
        react_ok(phone_number_id, from, message["id"]) if user.whatsapp_pending_question.nil?
        next
      end

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
