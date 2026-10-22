# frozen_string_literal: true

class ReplyWhatsappMessage
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

      # Unknown phone → new account. The agent asks for whatever the brief is missing.
      user ||= User.create!(whatsapp_phone: from)
      # Stored before this account existed, so the transcript can replay it.
      if (external_id = message["id"].to_s.presence)
        IncomingMessage.where(channel: "whatsapp", external_id:, user_id: nil).update_all(user_id: user.id)
      end

      if (decision = text.strip.match(/\Aapproval:(approve|reject):(\d+)\z/))
        handle_approval!(user, decision[1], decision[2].to_i, phone_number_id, from, message["id"])
        next
      end

      if (waiting = TransformationRun.waiting_for(user))
        waiting.remind!
        next
      end

      if (urls = Link.urls_in(text)).any?
        urls.each { |url| user.links.find_or_create_by!(url:) { it.source = "whatsapp" } }
        react_ok(phone_number_id, from, message["id"])
        next
      end

      response = RocketboxAgent.reply(user, text)

      reply = response.content.to_s.truncate(WHATSAPP_MAX_LENGTH)
      WhatsappCloud.send_text(phone_number_id:, to: from, body: reply) if from.present? && reply.present?
    end
  end

  private

    def handle_approval!(user, action, run_id, phone_number_id, from, message_id)
      run = TransformationRun.find_by(id: run_id)
      unless run&.waiting? && run.result&.user_id == user.id
        WhatsappCloud.send_text(phone_number_id:, to: from, body: "That approval is no longer pending.")
        return
      end

      action == "approve" ? run.approve! : run.reject!
      react_ok(phone_number_id, from, message_id)
      return if action == "approve"

      WhatsappCloud.send_text(phone_number_id:, to: from, body: "Rejected — won't post this one.")
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
