# frozen_string_literal: true

require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "active? reflects the active flag" do
    sub = subscriptions(:lazaro_nixon)
    sub.update!(active: true)
    assert_predicate sub, :active?

    sub.update!(active: false)
    assert_not sub.active?
  end
end
