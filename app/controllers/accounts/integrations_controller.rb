# frozen_string_literal: true

module Accounts
  class IntegrationsController < ApplicationController
    layout "app"

    def show
    end

    def update
      if Current.account.update(integrations_params)
        backfill_orphan_media!
        redirect_to profile_integrations_path, notice: "Account updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

      def integrations_params
        params.require(:user).permit(
          :instagram_user_id,
          :instagram_access_token,
          :telegram_user_id,
          :whatsapp_phone
        )
      end

      def backfill_orphan_media!
        if Current.account.telegram_user_id.present?
          LibraryMedia.where(from_id: Current.account.telegram_user_id, user_id: nil)
            .update_all(user_id: Current.account.id)
        end
        if Current.account.whatsapp_phone.present?
          LibraryMedia.where(whatsapp_from: Current.account.whatsapp_phone, user_id: nil)
            .update_all(user_id: Current.account.id)
        end
      end
  end
end
