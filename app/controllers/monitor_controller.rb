class MonitorController < ApplicationController
  layout "monitor"
  before_action :authenticate_admin!

  RESETS = {
    "name" => { name: nil },
    "business_name" => { business_name: nil },
    "verified" => { verified: false },
    "whatsapp" => { whatsapp_phone: nil, whatsapp_connect_code: nil },
    "instagram" => { instagram_user_id: nil, instagram_access_token: nil, instagram_profile: nil, instagram_avatar: nil },
    "telegram" => { telegram_user_id: nil }
  }.freeze

  def show
  end

  def onboarding
  end

  def reset_onboarding
    user = Current.account
    case step = params[:step]
    when *RESETS.keys then user.update!(RESETS[step])
    when "sessions" then user.sessions.where.not(id: Current.session.id).destroy_all
    when "draft" then session.delete(:signup)
    when "user"
      return redirect_to(monitor_onboarding_path, alert: "Can't delete yourself") if user == Current.user

      user.destroy!
    else
      return head(:unprocessable_entity)
    end

    redirect_to monitor_onboarding_path, notice: "Reset #{step}"
  end
end
