# frozen_string_literal: true

module StripeTestHelpers
  def stub_stripe_subscription_retrieve(returned)
    original = Stripe::Subscription.method(:retrieve)
    Stripe::Subscription.define_singleton_method(:retrieve) { |*_args| returned }
    yield
  ensure
    Stripe::Subscription.define_singleton_method(:retrieve, original)
  end

  def stub_stripe_webhook_construct_event
    original = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |payload, *_rest|
      JSON.parse(payload)
    end
    yield
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original)
  end
end

ActiveSupport.on_load(:active_support_test_case) { include StripeTestHelpers }
