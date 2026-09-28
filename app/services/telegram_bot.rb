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

  def send_message(chat_id:, text:)
    deliver!(:send_message, "text", text, chat_id:, text:)
  end

  def react(message)
    deliver!(:set_message_reaction, "reaction", "👍",
      chat_id: message.chat.id,
      message_id: message.message_id,
      reaction: [ { type: "emoji", emoji: "👍" } ]
    )
  rescue StandardError => e
    Rails.logger.warn("Telegram reaction failed: #{e.class}: #{e.message}")
  end

  def deliver!(method, kind, body, **params)
    log = { channel: "telegram", recipient: params[:chat_id].to_s, kind:, body:, payload: params,
            user: User.find_by(telegram_user_id: params[:chat_id]) }
    result = client.api.public_send(method, **params)
    OutgoingMessage.log(**log, external_id: result.try(:message_id)&.to_s)
    result
  rescue => e
    OutgoingMessage.log(**log, error: "#{e.class}: #{e.message}") if log
    raise
  end

  def reset!
    @client = nil
  end
end
