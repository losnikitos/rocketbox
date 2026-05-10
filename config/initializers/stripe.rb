# frozen_string_literal: true

# Stripe keys live in encrypted credentials: bin/rails credentials:edit
#   stripe:
#     secret_key: sk_test_...      # https://docs.stripe.com/keys
#     webhook_secret: whsec_...   # Dashboard endpoint; local CLI uses STRIPE_WEBHOOK_SECRET (see Procfile.dev)
#     price_id: price_...         # recurring Price for Checkout (subscription mode)
module StripeCredentials
  class << self
    def secret_key
      Rails.application.credentials.dig(:stripe, :secret_key)
    end

    def webhook_secret
      if Rails.env.development? && ENV["STRIPE_WEBHOOK_SECRET"].present?
        ENV["STRIPE_WEBHOOK_SECRET"]
      else
        Rails.application.credentials.dig(:stripe, :webhook_secret)
      end
    end

    def price_id
      Rails.application.credentials.dig(:stripe, :price_id)
    end
  end
end

Stripe.api_key = StripeCredentials.secret_key
