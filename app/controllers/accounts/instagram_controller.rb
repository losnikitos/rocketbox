# frozen_string_literal: true

module Accounts
  class InstagramController < ApplicationController
    layout "app"

    def show
    end

    def destroy
      Current.account.update!(OnboardingController::RESETS["instagram"])
      redirect_to instagram_profile_path, notice: "Instagram disconnected."
    end
  end
end
