# frozen_string_literal: true

module Subscriptions
  class AccessesController < ApplicationController
    skip_before_action :authenticate

    def show
      email = SubscriptionLink.read(params[:t])

      unless email
        redirect_to new_subscription_path, alert: "That link is invalid or has expired. Request a new subscription link below."
        return
      end

      redirect_to sign_up_path(email_hint: email)
    end
  end
end
