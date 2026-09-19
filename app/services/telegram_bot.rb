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

  def reset!
    @client = nil
  end
end
