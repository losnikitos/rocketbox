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
    each_message do |message|
      next if StoreWhatsappMedia.media?(message)

      text = message.dig("text", "body").to_s
      next if text.blank?

      from = message["from"].to_s
      user = User.find_by(whatsapp_phone: from.presence)
      chat = Chat.create!
      response = chat
        .with_instructions(INSTRUCTIONS)
        .with_tools(ListMedia.new(user:))
        .ask(text)

      reply = response.content.to_s.truncate(WHATSAPP_MAX_LENGTH)
      WhatsappCloud.send_text(to: from, body: reply) if from.present? && reply.present?
    end
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
end
