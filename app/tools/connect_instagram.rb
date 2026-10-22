# frozen_string_literal: true

class ConnectInstagram < RubyLLM::Tool
  description "Sends a one-time link to connect the user's Instagram. Use when Instagram is missing and you are asking them to connect it."

  def initialize(user:)
    @user = user
  end

  def execute
    return { error: "No Rocketbox account linked. Connect WhatsApp from the WhatsApp page in your Rocketbox dashboard." } if @user.nil?

    url = WhatsappOnboarding.login_url(@user, to: "instagram")

    if @user.whatsapp_phone.present?
      WhatsappOnboarding.send_link!(
        @user,
        "Connect your Instagram. The link works once, for 1 hour.",
        url:,
        button: "Connect Instagram"
      )
      { sent: true, note: "CTA already sent; tell the user to tap Connect Instagram. Do not paste the URL." }
    else
      { url:, expires_in: "1 hour", note: "one-time; include this URL in your reply" }
    end
  end
end
