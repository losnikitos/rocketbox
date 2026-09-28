# frozen_string_literal: true

module Accounts
  class AdminController < ApplicationController
    layout "app"
    before_action :authenticate_admin!

    def show
    end
  end
end
