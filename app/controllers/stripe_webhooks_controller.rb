# frozen_string_literal: true

class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    secret = ENV["STRIPE_WEBHOOK_SECRET"]

    if secret.blank?
      Rails.logger.error("STRIPE_WEBHOOK_SECRET is not configured")
      head :unprocessable_entity
      return
    end

    Stripe::Webhook.construct_event(payload, sig_header, secret)
    ProcessStripeWebhookJob.perform_later(payload)
    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue Stripe::SignatureVerificationError
    head :bad_request
  end
end
