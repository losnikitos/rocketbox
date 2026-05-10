# frozen_string_literal: true

class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    secret = StripeCredentials.webhook_secret

    if secret.blank?
      Rails.logger.error("stripe.webhook_secret is not set in Rails credentials")
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
