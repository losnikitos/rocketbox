# frozen_string_literal: true

class RocketboxAgent < RubyLLM::Agent
  chat_model Chat
  inputs :user

  # Label => User column. Same columns a business card writes, plus hours.
  BRIEF = {
    "Business name" => :business_name,
    "Phone" => :phone,
    "Contact name" => :name,
    "Address" => :address,
    "Website" => :homepage_url,
    "Description" => :business_description,
    "Hours" => :business_hours
  }.freeze

  instructions <<~TEXT.squish
    You are Rocketbox. You handle marketing for the user's business.
    A status and a list of what we know follows. Onboarding is INCOMPLETE while any line says (missing).
    A photo shows up as text, like "Sent a photo". You cannot see the image; a workflow reads it. They can also just tell you.
    When they state a fact, save it with save_business. Only save what they said. Never invent a value.
    Use list_media for questions about their media library.
    Use login_link when they ask to log in, open the dashboard, or get a login link.
    WhatsApp and Instagram are connections, not facts. If Instagram is (missing) and that is the one thing you are asking for, call connect_instagram and tell them to tap Connect Instagram; do not paste a URL or ask for a handle. If WhatsApp is (missing), suggest connecting WhatsApp.
    Keep replies to one short plain-text message. When onboarding is INCOMPLETE, ask for one missing fact.
    When onboarding is COMPLETE, ask them to send photos of their work (haircuts for a barbershop, matching the description). At least 2 photos are needed to compose the first Instagram reel.
    A tool result is a workflow that already ran. Confirm what it changed, then ask for one missing fact if onboarding is INCOMPLETE, or for photos of their work if it is COMPLETE.
  TEXT

  instructions append: true, persist: false do
    RocketboxAgent.business_brief(user)
  end

  tools { [ ListMedia.new(user:), LoginLink.new(user:), ConnectInstagram.new(user:), SaveBusiness.new(user:) ] }

  # One chat per user. Wiped and rebuilt from their messages and workflow runs; the brief above is the account.
  # `text` is a line the user did not send (a connection, a nudge). Their own words are already incoming messages.
  def self.reply(user, text = nil)
    chat = user.with_lock { user.chat || user.create_chat! }
    chat.messages.destroy_all
    AgentTranscript.call(chat, user)
    chat.add_message(role: :user, content: text) if text.present? && chat.messages.where(role: "user").order(:id).last&.content != text
    find(chat.id, user:).complete
  end

  # WhatsApp when they have a phone, otherwise Telegram.
  def self.deliver(user, text)
    body = text.to_s.truncate(4096)
    return if user.nil? || body.blank?

    if user.whatsapp_phone.present?
      WhatsappCloud.send_text(phone_number_id: WhatsappCloud.phone_number_id, to: user.whatsapp_phone, body:)
    elsif user.telegram_user_id.present?
      TelegramBot.send_message(chat_id: user.telegram_user_id, text: body)
    end
  end

  # The system messages a reply sends, in order. The brief is the second one.
  def self.system_messages(user)
    runtime = Object.new
    runtime.define_singleton_method(:user) { user }
    instructions.filter_map do |declaration|
      value = declaration[:value]
      text = value.is_a?(Proc) ? runtime.instance_exec(&value) : value
      text.to_s.presence
    end
  end

  def self.business_brief(user)
    return "No Rocketbox account linked." if user.nil?

    lines = BRIEF.map { |label, column| "#{label}: #{user.public_send(column).presence || "(missing)"}" }
    lines << "Logo: #{user.logo? ? "set" : "(missing)"}"
    lines << "WhatsApp: #{user.whatsapp_phone.present? ? "connected" : "(missing)"}"
    lines << "Instagram: #{user.instagram_authorized? ? "connected" : "(missing)"}"
    status = lines.any? { it.end_with?("(missing)") } ? "INCOMPLETE" : "COMPLETE"
    "Onboarding: #{status}\n#{lines.join("\n")}"
  end
end
