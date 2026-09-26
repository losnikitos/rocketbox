# frozen_string_literal: true

require "test_helper"

class Accounts::AccountSelectionsControllerTest < ActionDispatch::IntegrationTest
  test "admin sees customer selector and can switch accounts" do
    admin = sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)

    get library_uploads_url
    assert_response :success
    assert_select "select#account_user_id"
    assert_select "select#account_user_id option[value=?]", admin.id.to_s
    assert_select "select#account_user_id option[value=?]", customer.id.to_s

    patch account_selection_url, params: { user_id: customer.id }, headers: { "HTTP_REFERER" => library_uploads_url }
    assert_redirected_to library_uploads_url

    get business_url
    assert_response :success
    assert_select "select#account_user_id option[selected][value=?]", customer.id.to_s
    assert_select "input[name='user[business_name]'][value=?]", customer.business_name

    patch business_url, params: {
      user: { business_name: "Switched Shop", business_hours: "Mon–Fri 9–5" }
    }
    assert_redirected_to business_path
    assert_equal "Switched Shop", customer.reload.business_name
    assert_equal "Rocketbox Admin", admin.reload.business_name
  end

  test "non-admin cannot switch accounts or see selector" do
    sign_in_as(users(:lazaro_nixon))

    get library_uploads_url
    assert_response :success
    assert_select "select#account_user_id", count: 0

    patch account_selection_url, params: { user_id: users(:admin_user).id }
    assert_response :forbidden
  end
end
