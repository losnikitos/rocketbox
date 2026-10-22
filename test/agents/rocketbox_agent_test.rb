# frozen_string_literal: true

require "test_helper"

class RocketboxAgentTest < ActiveSupport::TestCase
  test "business brief shows the set name and missing fields" do
    user = users(:lazaro_nixon)
    user.update!(
      business_name: "Wick Lane Barbershop",
      phone: nil, name: nil, address: nil, homepage_url: nil,
      business_description: nil, business_hours: nil
    )

    brief = RocketboxAgent.business_brief(user)

    assert_includes brief, "- Business name: Wick Lane Barbershop"
    assert_includes brief, "- Phone: (missing)"
    assert_includes brief, "- Contact name: (missing)"
    assert_includes brief, "- Address: (missing)"
    assert_includes brief, "- Website: (missing)"
    assert_includes brief, "- Description: (missing)"
    assert_includes brief, "- Hours: (missing)"
    assert_includes brief, "- Logo: (missing)"
  end
end
