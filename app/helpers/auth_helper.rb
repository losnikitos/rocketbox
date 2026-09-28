# frozen_string_literal: true

module AuthHelper
  def auth_back_path
    case "#{controller_path}##{action_name}"
    when "sessions#otp" then sign_in_path(email_hint: @email)
    else root_path
    end
  end
end
