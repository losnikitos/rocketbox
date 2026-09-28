# frozen_string_literal: true

module Accounts
  class OnboardingController < ApplicationController
    layout "app"

    RESETS = {
      "whatsapp" => { whatsapp_phone: nil, whatsapp_pending_question: nil },
      "instagram" => { instagram_user_id: nil, instagram_access_token: nil, instagram_profile: nil, instagram_avatar: nil },
      "brand_voice" => { brand_voice: nil },
      "telegram" => { telegram_user_id: nil }
    }.freeze

    def show
    end

    def ask
      user = Current.account
      return head(:unprocessable_entity) unless WhatsappOnboarding::MESSAGES.key?(params[:field])

      WhatsappOnboarding.ask!(user, params[:field])
      redirect_back_or_to onboarding_path, notice: "Sent to +#{user.whatsapp_phone}"
    rescue WhatsappCloud::Error => e
      redirect_back_or_to onboarding_path, alert: e.message
    end

    def dashboard_link
      user = Current.account
      WhatsappOnboarding.send_link!(user, "Your Rocketbox dashboard. The link works once, for 1 hour.", url: WhatsappOnboarding.login_url(user), button: "Open dashboard")
      redirect_to onboarding_path, notice: "Dashboard link sent to +#{user.whatsapp_phone}"
    rescue WhatsappCloud::Error => e
      redirect_to onboarding_path, alert: e.message
    end

    def reset
      user = Current.account
      case step = params[:step]
      when *RESETS.keys then user.update!(RESETS[step])
      when "sessions" then user.sessions.where.not(id: Current.session.id).destroy_all
      when "user"
        return redirect_to(onboarding_path, alert: "Can't delete yourself") if user == Current.user

        user.destroy!
      else
        return head(:unprocessable_entity)
      end

      redirect_to onboarding_path, notice: "Reset #{step}"
    end
  end
end
