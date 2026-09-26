# frozen_string_literal: true

module Subscriptions
  class AccessesController < ApplicationController
    skip_before_action :authenticate

    def show
      email = SubscriptionLink.read(params[:t])

      unless email
        redirect_to new_subscribe_path, alert: "That link is invalid or has expired. Request a new subscription link below."
        return
      end

      session[:signup] = (session[:signup] || {}).merge("email" => email)
      redirect_to sign_up_name_path
    end
  end
end
