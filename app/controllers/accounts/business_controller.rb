# frozen_string_literal: true

module Accounts
  class BusinessController < ApplicationController
    layout "app"

    def show
    end

    def update
      attrs = business_params
      attrs.delete(:logo) if attrs[:logo].blank?

      if Current.account.update(attrs)
        redirect_to business_path, notice: "Business updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

      def business_params
        params.require(:user).permit(:business_name, :business_hours, :logo)
      end
  end
end
