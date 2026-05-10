# frozen_string_literal: true

require "test_helper"

class StripeSubscriptionSyncTest < ActiveSupport::TestCase
  test "activates subscription for active status and user metadata" do
    user = users(:lazaro_nixon)
    stripe_sub = Stripe::Subscription.construct_from(
      id: "sub_test_1",
      object: "subscription",
      customer: "cus_test_1",
      status: "active",
      current_period_end: 1.month.from_now.to_i,
      metadata: { "user_id" => user.id.to_s }
    )

    StripeSubscriptionSync.call(stripe_subscription: stripe_sub)

    sub = user.subscription.reload
    assert sub.active?
    assert_equal "active", sub.status
    assert_equal "sub_test_1", sub.stripe_subscription_id
    assert_equal "cus_test_1", sub.stripe_customer_id
    assert sub.current_period_end.present?
  end

  test "deactivates for canceled status" do
    user = users(:lazaro_nixon)
    user.subscription.update!(active: true, stripe_subscription_id: "sub_old", stripe_customer_id: "cus_old")

    stripe_sub = Stripe::Subscription.construct_from(
      id: "sub_old",
      object: "subscription",
      customer: "cus_old",
      status: "canceled",
      current_period_end: nil,
      metadata: { "user_id" => user.id.to_s }
    )

    StripeSubscriptionSync.call(stripe_subscription: stripe_sub)

    sub = user.subscription.reload
    assert_not sub.active?
    assert_equal "canceled", sub.status
  end

  test "trialing grants access" do
    user = users(:lazaro_nixon)
    stripe_sub = Stripe::Subscription.construct_from(
      id: "sub_trial",
      object: "subscription",
      customer: "cus_trial",
      status: "trialing",
      current_period_end: 1.week.from_now.to_i,
      metadata: { "user_id" => user.id.to_s }
    )

    StripeSubscriptionSync.call(stripe_subscription: stripe_sub)

    assert user.subscription.reload.active?
  end
end
