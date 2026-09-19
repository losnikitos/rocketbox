# frozen_string_literal: true

require "telegram/bot"

class ReplyTelegramMessage
  INSTRUCTIONS = <<~TEXT.squish
    You are the Rocketbox library assistant.
    Use the list_media tool to answer questions about the user's media library.
    Keep replies short and plain text.
  TEXT

  TELEGRAM_MAX_LENGTH = 4096

  def self.call(update)
    new(update).call
  end

  def initialize(update)
    @update = update.is_a?(Hash) ? Telegram::Bot::Types::Update.new(update) : update
  end

  def call
    message = @update.message || @update.edited_message
    return if message.blank? || message.text.blank?
    return if StoreTelegramMedia.media?(message)

    user = User.find_by(telegram_user_id: message.from&.id)
    chat = Chat.create!
    response = chat
      .with_instructions(INSTRUCTIONS)
      .with_tools(ListMedia.new(user:))
      .ask(message.text)

    text = response.content.to_s.truncate(TELEGRAM_MAX_LENGTH)
    TelegramBot.client.api.send_message(chat_id: message.chat.id, text: text)
  end
end
