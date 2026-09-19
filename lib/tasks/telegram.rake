# frozen_string_literal: true

require "telegram/bot"

namespace :telegram do
  desc "Long-poll Telegram updates (local/dev). Deletes webhook first."
  task poll: :environment do
    TelegramBot.client.api.delete_webhook
    puts "Polling as @#{TelegramBot.client.api.get_me.username}…"

    TelegramBot.client.listen do |payload|
      next unless payload.is_a?(Telegram::Bot::Types::Message)

      ProcessTelegramUpdateJob.perform_now(
        "update_id" => 0,
        "message" => payload.as_json
      )
    end
  end

  desc "Set Telegram webhook URL. Usage: rails telegram:set_webhook[https://rocketbox.plus/telegram/webhook]"
  task :set_webhook, [ :url ] => :environment do |_t, args|
    url = args[:url].presence || raise("pass url: rails telegram:set_webhook[https://host/telegram/webhook]")
    opts = { url: url }
    if secret = Rails.application.credentials.dig(:telegram, :webhook_secret).presence
      opts[:secret_token] = secret
    end
    TelegramBot.client.api.set_webhook(**opts)
    puts TelegramBot.client.api.get_webhook_info
  end
end
