# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  def show
    @subscription = Current.user.subscription
  end

  def checkout
    price_id = StripeCredentials.price_id
    if price_id.blank?
      redirect_to subscription_path, alert: "Subscription billing is not configured."
      return
    end

    if Stripe.api_key.blank?
      redirect_to subscription_path, alert: "Stripe is not configured."
      return
    end

    sub = Current.user.subscription
    session_params = {
      mode: "subscription",
      line_items: [ { price: price_id, quantity: 1 } ],
      success_url: subscription_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: subscription_url,
      client_reference_id: Current.user.id.to_s,
      metadata: { user_id: Current.user.id.to_s },
      subscription_data: { metadata: { user_id: Current.user.id.to_s } }
    }

    if sub.stripe_customer_id.present?
      session_params[:customer] = sub.stripe_customer_id
    else
      session_params[:customer_email] = Current.user.email
    end

    session = Stripe::Checkout::Session.create(session_params)
    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[Stripe checkout] #{e.class}: #{e.message}")
    redirect_to subscription_path, alert: "Could not start checkout. Please try again."
  end

  def portal
    sub = Current.user.subscription
    if sub.stripe_customer_id.blank?
      redirect_to subscription_path, alert: "Subscribe first to manage billing."
      return
    end

    session = Stripe::BillingPortal::Session.create(
      customer: sub.stripe_customer_id,
      return_url: subscription_url
    )
    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[Stripe portal] #{e.class}: #{e.message}")
    redirect_to subscription_path, alert: "Could not open billing portal. Please try again."
  end
end
