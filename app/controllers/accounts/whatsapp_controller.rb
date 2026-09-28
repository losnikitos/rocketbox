# frozen_string_literal: true

module Accounts
  class WhatsappController < ApplicationController
    layout "app"

    def show
      return if Current.account.whatsapp_phone

      Current.account.regenerate_whatsapp_link_code unless Current.account.whatsapp_link_code
      @whatsapp_url = "https://wa.me/#{WhatsappCloud.display_phone}?text=START_#{Current.account.whatsapp_link_code}"
    end

    def destroy
      Current.account.update!(OnboardingController::RESETS["whatsapp"])
      redirect_to whatsapp_path, notice: "WhatsApp disconnected."
    end
  end
end
