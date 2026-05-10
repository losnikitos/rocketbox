# frozen_string_literal: true

require "test_helper"

class ProcessStripeWebhookJobTest < ActiveJob::TestCase
  test "checkout.session.completed syncs subscription" do
    user = users(:lazaro_nixon)
    payload = {
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "mode" => "subscription",
          "subscription" => "sub_from_checkout",
          "client_reference_id" => user.id.to_s,
          "customer" => "cus_from_checkout"
        }
      }
    }.to_json

    stripe_sub = Stripe::Subscription.construct_from(
      id: "sub_from_checkout",
      object: "subscription",
      customer: "cus_from_checkout",
      status: "active",
      current_period_end: 1.month.from_now.to_i,
      metadata: { "user_id" => user.id.to_s }
    )

    stub_stripe_subscription_retrieve(stripe_sub) do
      ProcessStripeWebhookJob.perform_now(payload)
    end

    sub = user.subscription.reload
    assert_equal "cus_from_checkout", sub.stripe_customer_id
    assert sub.active?
    assert_equal "sub_from_checkout", sub.stripe_subscription_id
  end

  test "customer.subscription.updated refreshes from Stripe" do
    user = users(:lazaro_nixon)
    payload = {
      "type" => "customer.subscription.updated",
      "data" => {
        "object" => {
          "id" => "sub_updated"
        }
      }
    }.to_json

    stripe_sub = Stripe::Subscription.construct_from(
      id: "sub_updated",
      object: "subscription",
      customer: "cus_x",
      status: "past_due",
      current_period_end: Time.now.to_i,
      metadata: { "user_id" => user.id.to_s }
    )

    stub_stripe_subscription_retrieve(stripe_sub) do
      ProcessStripeWebhookJob.perform_now(payload)
    end

    sub = user.subscription.reload
    assert_equal "past_due", sub.status
    assert_not sub.active?
  end
end
