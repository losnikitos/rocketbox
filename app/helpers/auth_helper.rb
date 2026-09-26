# frozen_string_literal: true

module AuthHelper
  def auth_back_path
    case "#{controller_path}##{action_name}"
    when "signups#name" then root_path
    when "signups#business" then sign_up_name_path
    when "signups#email" then sign_up_business_path
    when "signups#email_code" then sign_up_email_path
    when "signups#phone" then sign_up_email_code_path
    when "signups#phone_code" then sign_up_phone_path
    when "sessions#new" then root_path
    when "sessions#otp" then sign_in_path(email_hint: @email)
    else root_path
    end
  end
end
