# frozen_string_literal: true

class ProcessStripeWebhookJob < ApplicationJob
  queue_as :default

  def perform(event_json)
    data = JSON.parse(event_json)
    type = data["type"]
    object = data.dig("data", "object")
    return if object.blank?

    case type
    when "checkout.session.completed"
      handle_checkout_completed(object)
    when "customer.subscription.updated"
      StripeSubscriptionSync.call(stripe_subscription: object["id"])
    when "customer.subscription.deleted"
      StripeSubscriptionSync.call(stripe_subscription: object["id"])
    end
  end

  private

    def handle_checkout_completed(session)
      return if session["mode"] != "subscription"

      subscription_id = session["subscription"]
      return if subscription_id.blank?

      user_id = session["client_reference_id"]
      customer_id = session["customer"]
      if user_id.present? && customer_id.present?
        user = User.find_by(id: user_id)
        user&.subscription&.update!(stripe_customer_id: customer_id)
      end

      StripeSubscriptionSync.call(stripe_subscription: subscription_id)
    end
end
