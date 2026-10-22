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
    A photo of their business card is enough: we read the logo, name, phone, website, address, and description from it. They can also just tell you.
    When they state a fact, save it with save_business. Only save what they said. Never invent a value.
    Use list_media for questions about their media library.
    Use login_link when they ask to log in, open the dashboard, or get a login link.
    Keep replies to one short plain-text message. When onboarding is INCOMPLETE, ask for one missing fact.
    A tool result is a workflow that already ran. Confirm what it changed, then ask for one missing fact if onboarding is INCOMPLETE.
  TEXT

  instructions append: true, persist: false do
    RocketboxAgent.business_brief(user)
  end

  tools { [ ListMedia.new(user:), LoginLink.new(user:), SaveBusiness.new(user:) ] }

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

  def self.business_brief(user)
    return "No Rocketbox account linked." if user.nil?

    lines = BRIEF.map { |label, column| "#{label}: #{user.public_send(column).presence || "(missing)"}" }
    lines << "Logo: #{user.logo? ? "set" : "(missing)"}"
    status = lines.any? { it.end_with?("(missing)") } ? "INCOMPLETE" : "COMPLETE"
    "Onboarding: #{status}\n#{lines.join("\n")}"
  end
end
