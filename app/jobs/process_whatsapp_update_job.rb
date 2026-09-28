# frozen_string_literal: true

class ProcessWhatsappUpdateJob < ApplicationJob
  queue_as :default

  def perform(payload)
    payload = payload.is_a?(Hash) ? payload : {}

    messages = []
    Array(payload["entry"]).each do |entry|
      Array(entry["changes"]).each do |change|
        next unless change["field"] == "messages"

        messages.concat(Array(change.dig("value", "messages")))
      end
    end
    return if messages.empty?

    messages.reject { it.dig("text", "body").to_s.strip.match?(WhatsappOnboarding::LINK_PATTERN) }
      .filter_map { it["from"].presence }.uniq.each { User.find_or_create_by!(whatsapp_phone: it) }
    messages.each { |message| StoreIncomingMessage.whatsapp(message) }

    if messages.any? { |message| StoreWhatsappMedia.media?(message) }
      StoreWhatsappMedia.call(payload)
    end

    if messages.any? { |message| message["type"].in?(%w[text interactive]) }
      ReplyWhatsappMessage.call(payload)
    end
  end
end
