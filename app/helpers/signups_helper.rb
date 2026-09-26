# frozen_string_literal: true

module SignupsHelper
  def signup_back_path
    case action_name
    when "name" then root_path
    when "business" then sign_up_name_path
    when "email" then sign_up_business_path
    when "email_code" then sign_up_email_path
    when "phone" then sign_up_email_code_path
    when "phone_code" then sign_up_phone_path
    else root_path
    end
  end
end
