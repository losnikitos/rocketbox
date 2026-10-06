# frozen_string_literal: true

require "test_helper"

class AdminAccountParamTest < ActionDispatch::IntegrationTest
  test "admin URLs always carry the viewed business" do
    admin = sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)

    get library_folders_url("inbox")
    assert_redirected_to library_folders_url("inbox", account: admin.id)

    get app_url(account: customer.id)
    assert_redirected_to recent_url(account: customer.id)

    get business_url(account: customer.id)
    assert_response :success
    assert_select "select#account_user_id option[value=?]", admin.id.to_s
    assert_select "select#account_user_id option[selected][value=?]", customer.id.to_s
    assert_select "input[name='user[business_name]'][value=?]", customer.business_name
    assert_select "nav[aria-label='Primary'] a[href=?]", reviews_path(account: customer.id)

    get "/app/reviews?archived=1"
    assert_redirected_to reviews_url(archived: 1, account: customer.id)

    patch business_url(account: customer.id), params: {
      user: { business_name: "Switched Shop", business_hours: "Mon–Fri 9–5" }
    }
    assert_redirected_to business_url(account: customer.id)
    assert_equal "Switched Shop", customer.reload.business_name
    assert_equal "Rocketbox Admin", admin.reload.business_name

    get business_url(account: "nope")
    assert_redirected_to business_url(account: admin.id)
  end

  test "non-admin ignores the account param and sees no selector" do
    sign_in_as(users(:lazaro_nixon))

    get library_folders_url("inbox", account: users(:admin_user).id)
    assert_response :success
    assert_select "select#account_user_id", count: 0
    assert_select "nav[aria-label='Primary'] a[href=?]", reviews_path
  end
end
