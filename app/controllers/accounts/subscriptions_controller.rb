# frozen_string_literal: true

module Accounts
  class SubscriptionsController < ApplicationController
    layout "app"

    def show
      @subscription = Current.account.subscription
    end
  end
end
