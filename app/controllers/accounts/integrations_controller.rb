# frozen_string_literal: true

module Accounts
  class IntegrationsController < ApplicationController
    def show
    end

    def update
      if Current.user.update(integrations_params)
        if Current.user.telegram_user_id.present?
          TelegramUpload.where(from_id: Current.user.telegram_user_id, user_id: nil)
            .update_all(user_id: Current.user.id)
        end
        redirect_to account_integrations_path, notice: "Account updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

      def integrations_params
        params.require(:user).permit(:instagram_user_id, :instagram_access_token, :telegram_user_id)
      end
  end
end
