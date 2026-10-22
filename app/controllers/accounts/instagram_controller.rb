# frozen_string_literal: true

module Accounts
  class InstagramController < ApplicationController
    layout "app"

    def show
      return if Current.account.instagram_authorized?

      @instagram_connect_url = WhatsappOnboarding.login_url(Current.account, to: "instagram")
    end

    def link
      user = Current.account
      return redirect_to(instagram_profile_path, alert: "Connect WhatsApp first.") if user.whatsapp_phone.blank?

      WhatsappOnboarding.send_link!(
        user,
        "Connect your Instagram. The link works once, for 1 hour.",
        url: WhatsappOnboarding.login_url(user, to: "instagram"),
        button: "Connect Instagram"
      )
      redirect_to instagram_profile_path, notice: "Link sent to +#{user.whatsapp_phone}"
    rescue WhatsappCloud::Error => e
      redirect_to instagram_profile_path, alert: e.message
    end

    def destroy
      Current.account.update!(OnboardingController::RESETS["instagram"])
      redirect_to instagram_profile_path, notice: "Instagram disconnected."
    end
  end
end
