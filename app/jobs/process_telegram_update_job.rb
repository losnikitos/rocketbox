# frozen_string_literal: true

require "telegram/bot"

class ProcessTelegramUpdateJob < ApplicationJob
  queue_as :default

  def perform(update)
    parsed = update.is_a?(Hash) ? Telegram::Bot::Types::Update.new(update) : update
    message = parsed.message || parsed.edited_message
    return if message.blank?

    StoreIncomingMessage.telegram(message)

    if StoreTelegramMedia.media?(message)
      StoreTelegramMedia.call(update)
    elsif message.text.present?
      ReplyTelegramMessage.call(update)
    end
  end
end
