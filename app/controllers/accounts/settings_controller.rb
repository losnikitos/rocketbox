# frozen_string_literal: true

module Accounts
  class SettingsController < ApplicationController
    layout "app"

    def show
    end

    def update
      if Current.account.update(settings_params)
        UserMailer.with(user: Current.account).email_verification.deliver_later if Current.account.email_previously_changed? && Current.account.email
        return head :ok if autosave_request?

        redirect_to profile_settings_path, notice: "Account updated."
      else
        return render_autosave_error(Current.account) if autosave_request?

        render :show, status: :unprocessable_entity
      end
    end

    private

      def settings_params
        params.require(:user).permit(:name, :email, :password)
      end
  end
end
