# frozen_string_literal: true

# Use test keys from the Stripe Dashboard (Developers → API keys) during development.
# https://docs.stripe.com/keys
Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
