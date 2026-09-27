# frozen_string_literal: true

module Accounts
  class InstagramAuthorizationsController < ApplicationController
    def new
      session[:instagram_oauth_state] = state = SecureRandom.hex(16)
      redirect_to InstagramOauth.authorize_url(redirect_uri: profile_instagram_callback_url, state:), allow_other_host: true
    rescue InstagramOauth::Error => e
      redirect_to profile_integrations_path, alert: e.message
    end

    def callback
      state = session.delete(:instagram_oauth_state).to_s
      if state.blank? || !ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)
        return redirect_to profile_integrations_path, alert: "Instagram authorization expired. Try again."
      end
      if params[:code].blank?
        return redirect_to profile_integrations_path, alert: params[:error_description].presence || "Instagram authorization was cancelled."
      end

      user_id, token = InstagramOauth.exchange(code: params[:code], redirect_uri: profile_instagram_callback_url)
      Current.account.update!(instagram_user_id: user_id, instagram_access_token: token)
      redirect_to profile_integrations_path, notice: "Instagram authorized."
    rescue InstagramOauth::Error => e
      redirect_to profile_integrations_path, alert: e.message
    end
  end
end
