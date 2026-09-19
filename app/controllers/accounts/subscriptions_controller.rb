# frozen_string_literal: true

module Accounts
  class SubscriptionsController < ApplicationController
    def show
      @subscription = Current.user.subscription
    end
  end
end
