# frozen_string_literal: true

class TelegramWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  def create
    if secret = Rails.application.credentials.dig(:telegram, :webhook_secret).presence
      unless ActiveSupport::SecurityUtils.secure_compare(request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s, secret)
        head :unauthorized
        return
      end
    end

    ProcessTelegramUpdateJob.perform_later(JSON.parse(request.body.read))
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end
end
