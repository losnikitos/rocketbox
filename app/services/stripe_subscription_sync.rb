# frozen_string_literal: true

class StripeSubscriptionSync
  def self.call(stripe_subscription:)
    new(stripe_subscription:).call
  end

  def initialize(stripe_subscription:)
    @stripe_subscription =
      case stripe_subscription
      when Stripe::Subscription
        stripe_subscription
      when String
        Stripe::Subscription.retrieve(stripe_subscription)
      else
        raise ArgumentError, "Expected Stripe::Subscription or id String"
      end
  end

  def call
    user = find_user
    return if user.blank?

    sub = user.subscription
    period_end = @stripe_subscription.current_period_end
    sub.update!(
      stripe_customer_id: @stripe_subscription.customer,
      stripe_subscription_id: @stripe_subscription.id,
      status: @stripe_subscription.status,
      current_period_end: period_end ? Time.zone.at(period_end).utc : nil,
      active: Subscription.stripe_status_grants_access?(@stripe_subscription.status)
    )
  end

  private

  def find_user
    meta_uid = @stripe_subscription.metadata&.[]("user_id")
    return User.find_by(id: meta_uid) if meta_uid.present?

    cid = @stripe_subscription.customer
    return if cid.blank?

    User.joins(:subscription).find_by(subscriptions: { stripe_customer_id: cid })
  end
end
