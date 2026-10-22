# frozen_string_literal: true

require "telegram/bot"

class ReplyTelegramMessage
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
    return if user.nil?

    if (urls = Link.urls_in(message.text)).any?
      urls.each { |url| user.links.find_or_create_by!(url:) { it.source = "telegram" } }
      return TelegramBot.react(message)
    end

    response = RocketboxAgent.reply(user, message.text)

    text = response.content.to_s.truncate(TELEGRAM_MAX_LENGTH)
    TelegramBot.send_message(chat_id: message.chat.id, text: text) if text.present?
  end
end
