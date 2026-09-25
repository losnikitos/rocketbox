# frozen_string_literal: true

module Accounts
  class SubscriptionsController < ApplicationController
    layout "app"

    def show
      @subscription = Current.user.subscription
    end
  end
end
