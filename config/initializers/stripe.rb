# frozen_string_literal: true

# Stripe keys live in encrypted credentials: bin/rails credentials:edit
#   stripe:
#     secret_key: sk_test_...      # https://docs.stripe.com/keys
#     webhook_secret: whsec_...   # Dashboard webhook endpoint or `stripe listen`
#     price_id: price_...         # recurring Price for Checkout (subscription mode)
module StripeCredentials
  class << self
    def secret_key
      Rails.application.credentials.dig(:stripe, :secret_key)
    end

    def webhook_secret
      Rails.application.credentials.dig(:stripe, :webhook_secret)
    end

    def price_id
      Rails.application.credentials.dig(:stripe, :price_id)
    end
  end
end

Stripe.api_key = StripeCredentials.secret_key
