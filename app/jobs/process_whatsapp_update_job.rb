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

    stored = messages.filter_map { |message| StoreIncomingMessage.whatsapp(message) }

    if messages.any? { |message| StoreWhatsappMedia.media?(message) }
      StoreWhatsappMedia.call(payload)
    end

    stored.filter_map(&:user).uniq.each(&:broadcast_whatsapp_thread)

    if messages.any? { |message| message["type"].in?(%w[text interactive]) }
      ReplyWhatsappMessage.call(payload)
    end
  end
end
