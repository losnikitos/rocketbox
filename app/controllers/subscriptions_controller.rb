# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  skip_before_action :authenticate, only: %i[new create thanks]

  def new
    @request = SubscriptionRequest.new
  end

  def create
    @request = SubscriptionRequest.new(subscription_params)

    if @request.valid?
      token = SubscriptionLink.generate!(@request.email)
      subscribe_url = subscription_access_url(t: token)
      SubscriptionMailer.with(email: @request.email, subscribe_url:).subscribe_magic_link.deliver_later
      redirect_to subscription_thanks_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def thanks
  end

  private

    def subscription_params
      params.expect(subscription_request: [:email])
    end
end
