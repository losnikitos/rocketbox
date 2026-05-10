# frozen_string_literal: true

require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "stripe_status_grants_access? matches paid Stripe statuses" do
    assert Subscription.stripe_status_grants_access?("active")
    assert Subscription.stripe_status_grants_access?("trialing")
    assert_not Subscription.stripe_status_grants_access?("canceled")
    assert_not Subscription.stripe_status_grants_access?("past_due")
  end

  test "active? reflects the active flag" do
    sub = subscriptions(:lazaro_nixon)
    sub.update!(active: true)
    assert_predicate sub, :active?

    sub.update!(active: false)
    assert_not sub.active?
  end
end
