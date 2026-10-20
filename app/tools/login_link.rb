# frozen_string_literal: true

class LoginLink < RubyLLM::Tool
  description "Sends the user a one-time link to open their Rocketbox dashboard. Use when they ask to log in, open the dashboard, or get a login link."

  def initialize(user:)
    @user = user
  end

  def execute
    return { error: "No Rocketbox account linked. Connect WhatsApp from the WhatsApp page in your Rocketbox dashboard." } if @user.nil?

    url = WhatsappOnboarding.login_url(@user)

    if @user.whatsapp_phone.present?
      WhatsappOnboarding.send_link!(
        @user,
        "Your Rocketbox dashboard. The link works once, for 1 hour.",
        url:,
        button: "Open dashboard"
      )
      { sent: true, note: "CTA already sent; tell the user to tap Open dashboard. Do not paste the URL." }
    else
      { url:, expires_in: "1 hour", note: "one-time; include this URL in your reply" }
    end
  end
end
