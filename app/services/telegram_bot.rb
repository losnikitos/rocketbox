# frozen_string_literal: true

require "telegram/bot"

module TelegramBot
  module_function

  def token
    Rails.application.credentials.dig(:telegram, :bot_token).presence ||
      raise("credentials.telegram.bot_token is missing")
  end

  def client
    @client ||= Telegram::Bot::Client.new(token)
  end

  def react(message)
    client.api.set_message_reaction(
      chat_id: message.chat.id,
      message_id: message.message_id,
      reaction: [ { type: "emoji", emoji: "👍" } ]
    )
  rescue StandardError => e
    Rails.logger.warn("Telegram reaction failed: #{e.class}: #{e.message}")
  end

  def reset!
    @client = nil
  end
end
