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
    A "What we know" list follows. Where a line says (missing), ask for it.
    A photo of their business card is enough: we read the logo, name, phone, website, address, and description from it. They can also just tell you.
    When they state a fact, save it with save_business. Only save what they said. Never invent a value.
    Use list_media for questions about their media library.
    Use login_link when they ask to log in, open the dashboard, or get a login link.
    Keep replies short and plain text.
    Instagram, interior photos, brand voice, and email are asked separately. Do not ask for those.
  TEXT

  instructions append: true do
    RocketboxAgent.business_brief(user)
  end

  tools { [ ListMedia.new(user:), LoginLink.new(user:), SaveBusiness.new(user:) ] }

  def self.business_brief(user)
    return "No Rocketbox account linked." if user.nil?

    lines = BRIEF.map { |label, column| "- #{label}: #{user.public_send(column).presence || "(missing)"}" }
    lines << "- Logo: #{user.logo? ? "set" : "(missing)"}"
    "What we know about this business:\n#{lines.join("\n")}"
  end
end
