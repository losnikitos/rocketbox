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

    if messages.any? { |message| StoreWhatsappMedia.media?(message) }
      StoreWhatsappMedia.call(payload)
    end

    if messages.any? { |message| message["type"] == "text" && message.dig("text", "body").present? }
      ReplyWhatsappMessage.call(payload)
    end
  end
end
