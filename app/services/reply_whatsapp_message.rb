# frozen_string_literal: true

class ReplyWhatsappMessage
  WHATSAPP_MAX_LENGTH = 4096

  # Text here is business details for the agent. The step stays set so the next photo still files.
  AGENT_ONBOARDING_STEPS = %w[business_card logo processing_business_card processing_logo].freeze

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

      # Unknown phone → new account + onboarding. Known phone → library / answers below.
      unless user
        user = User.create!(whatsapp_phone: from)
        WhatsappOnboarding.ask!(user, "business_card")
        next
      end

      if text.strip.casecmp?("start")
        WhatsappOnboarding.ask!(user, "business_card")
        next
      end

      if (decision = text.strip.match(/\Aapproval:(approve|reject):(\d+)\z/))
        handle_approval!(user, decision[1], decision[2].to_i, phone_number_id, from, message["id"])
        next
      end

      if WhatsappOnboarding.answer!(user, text)
        react_ok(phone_number_id, from, message["id"]) if user.whatsapp_pending_question.nil?
        next
      end

      if (step = user.whatsapp_pending_question).present? && AGENT_ONBOARDING_STEPS.exclude?(step)
        WhatsappOnboarding.ask!(user, step)
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

      response = RocketboxAgent.create!(user:).ask(text)

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
