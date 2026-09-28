# frozen_string_literal: true

module Accounts
  class OnboardingController < ApplicationController
    layout "app"
    before_action :authenticate_admin!

    RESETS = {
      "name" => { name: nil },
      "business_name" => { business_name: nil },
      "homepage_url" => { homepage_url: nil },
      "whatsapp" => { whatsapp_phone: nil, whatsapp_pending_question: nil },
      "instagram" => { instagram_user_id: nil, instagram_access_token: nil, instagram_profile: nil, instagram_avatar: nil },
      "telegram" => { telegram_user_id: nil }
    }.freeze

    def show
    end

    def ask
      user = Current.account
      case field = params[:field]
      when "instagram"
        WhatsappOnboarding.send_link!(user, whatsapp_login_url(user, to: "instagram"), "Connect your Instagram so we can post for you:")
      when *WhatsappOnboarding::PROMPTS.keys
        WhatsappOnboarding.ask!(user, field)
      else
        return head(:unprocessable_entity)
      end

      redirect_to ask_back_path, notice: "Sent to +#{user.whatsapp_phone}"
    rescue WhatsappCloud::Error => e
      redirect_to ask_back_path, alert: e.message
    end

    def dashboard_link
      user = Current.account
      WhatsappOnboarding.send_link!(user, whatsapp_login_url(user), "Your Rocketbox dashboard (the link works once, for 1 hour):")
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

    private

      def ask_back_path
        onboarding_path(tab: WhatsappOnboarding::MEDIA_REQUESTS.key?(params[:field]) ? "media" : "steps")
      end

      def whatsapp_login_url(user, **params)
        sign_in_whatsapp_url(token: user.generate_token_for(:whatsapp_login), **params)
      end
  end
end
