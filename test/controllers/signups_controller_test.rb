# frozen_string_literal: true

require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  test "show links to WhatsApp with START" do
    get sign_up_url

    assert_response :success
    assert_select "a[href=?]", "https://wa.me/#{WhatsappCloud.display_phone}?text=START", text: /Open WhatsApp/
  end
end
