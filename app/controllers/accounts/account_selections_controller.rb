# frozen_string_literal: true

module Accounts
  class AccountSelectionsController < ApplicationController
    def update
      unless Current.user&.admin?
        head :forbidden
        return
      end

      user_id = params[:user_id].to_i
      if user_id <= 0 || user_id == Current.user.id
        session.delete(:account_user_id)
      elsif User.exists?(id: user_id)
        session[:account_user_id] = user_id
      end

      redirect_back fallback_location: app_path
    end
  end
end
