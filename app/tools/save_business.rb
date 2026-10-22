# frozen_string_literal: true

class SaveBusiness < RubyLLM::Tool
  description "Saves business details the user just stated. Only include fields they actually gave you."

  parameter :business_name, required: false, description: "The business or brand name"
  parameter :phone, required: false, description: "The business phone number"
  parameter :name, required: false, description: "The contact person's name"
  parameter :address, required: false, description: "The street address"
  parameter :homepage_url, required: false, description: "The website URL"
  parameter :business_description, required: false, description: "What the business does"
  parameter :business_hours, required: false, description: "Opening hours"

  def initialize(user:)
    @user = user
  end

  def execute(business_name: nil, phone: nil, name: nil, address: nil, homepage_url: nil, business_description: nil, business_hours: nil)
    return { error: "No Rocketbox account linked. Connect WhatsApp from the WhatsApp page in your Rocketbox dashboard." } if @user.nil?

    attrs = {
      business_name:, phone:, name:, address:, homepage_url:, business_description:, business_hours:
    }.transform_values { it.to_s.strip }.compact_blank
    @user.update!(attrs) if attrs.any?
    RocketboxAgent.business_brief(@user)
  end
end
