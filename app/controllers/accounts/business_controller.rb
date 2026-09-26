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
        return head :ok if autosave_request?

        redirect_to business_path, notice: "Business updated."
      else
        return render_autosave_error(Current.account) if autosave_request?

        render :show, status: :unprocessable_entity
      end
    end

    private

      def business_params
        params.require(:user).permit(:business_name, :homepage_url, :business_hours, :logo)
      end
  end
end
