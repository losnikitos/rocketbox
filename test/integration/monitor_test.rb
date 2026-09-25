require "test_helper"

class MonitorTest < ActionDispatch::IntegrationTest
  test "admin can open monitor" do
    sign_in_as(users(:admin_user))

    get monitor_path
    assert_response :success
    assert_select "aside nav[aria-label=?]", "Monitor"
    assert_select "header nav[aria-label=?]", "Sections"
  end

  test "non-admin redirected to root" do
    sign_in_as(users(:lazaro_nixon))

    get monitor_path
    assert_redirected_to root_path
  end

  test "guest redirected to sign in" do
    get monitor_path
    assert_redirected_to sign_in_path
  end
end
