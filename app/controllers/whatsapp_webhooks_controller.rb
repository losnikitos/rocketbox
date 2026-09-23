# frozen_string_literal: true

class WhatsappWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  def show
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]
    expected = WhatsappCloud.webhook_verify_token

    if mode == "subscribe" && expected.present? && ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected)
      render plain: challenge, status: :ok
    else
      head :forbidden
    end
  end

  def create
    raw_body = request.body.read
    signature = request.headers["X-Hub-Signature-256"].to_s

    unless WhatsappCloud.valid_signature?(raw_body, signature)
      head :unauthorized
      return
    end

    ProcessWhatsappUpdateJob.perform_later(JSON.parse(raw_body))
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end
end
