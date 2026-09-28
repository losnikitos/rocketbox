# frozen_string_literal: true

module Subscriptions
  class AccessesController < ApplicationController
    skip_before_action :authenticate

    def show
      unless SubscriptionLink.read(params[:t])
        redirect_to new_subscribe_path, alert: "That link is invalid or has expired. Request a new subscription link below."
        return
      end

      redirect_to sign_up_path
    end
  end
end
