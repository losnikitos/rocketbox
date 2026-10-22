# frozen_string_literal: true

require "test_helper"

class SaveBusinessTest < ActiveSupport::TestCase
  test "writes the stated name and leaves phone untouched" do
    user = users(:lazaro_nixon)
    user.update!(business_name: nil, phone: "555")

    SaveBusiness.new(user:).execute(business_name: "Wick Lane Barbershop")

    user.reload
    assert_equal "Wick Lane Barbershop", user.business_name
    assert_equal "555", user.phone
  end
end
