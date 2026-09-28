# frozen_string_literal: true

module Accounts
  class InstagramAuthorizationsController < ApplicationController
    def new
      session[:instagram_oauth_state] = state = SecureRandom.hex(16)
      redirect_to InstagramOauth.authorize_url(redirect_uri: profile_instagram_callback_url, state:), allow_other_host: true
    rescue InstagramOauth::Error => e
      redirect_to instagram_profile_path, alert: e.message
    end

    def callback
      state = session.delete(:instagram_oauth_state).to_s
      if state.blank? || !ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)
        return redirect_to instagram_profile_path, alert: "Instagram authorization expired. Try again."
      end
      if params[:code].blank?
        return redirect_to instagram_profile_path, alert: params[:error_description].presence || "Instagram authorization was cancelled."
      end

      Current.account.update!(instagram_access_token: InstagramOauth.exchange(code: params[:code], redirect_uri: profile_instagram_callback_url))
      Current.account.refresh_instagram_profile!
      redirect_to instagram_profile_path, notice: "Instagram authorized."
    rescue InstagramOauth::Error => e
      redirect_to instagram_profile_path, alert: e.message
    end

    def refresh
      Current.account.refresh_instagram_profile!
      redirect_to instagram_profile_path, notice: "Instagram info updated."
    rescue InstagramOauth::Error => e
      redirect_to instagram_profile_path, alert: e.message
    end
  end
end
