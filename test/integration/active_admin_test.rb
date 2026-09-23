require "test_helper"

class ActiveAdminTest < ActionDispatch::IntegrationTest
  setup do
    @ua = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" }
  end

  test "anon redirects to sign in" do
    get "/admin", headers: @ua
    assert_redirected_to sign_in_path
  end

  test "non-admin redirected to root" do
    sign_in_as(users(:lazaro_nixon))
    get "/admin", headers: @ua
    assert_redirected_to root_path
  end

  test "admin can open dashboard" do
    sign_in_as(users(:admin_user))
    get "/admin", headers: @ua
    assert_response :success
    assert_match(/Dashboard/i, response.body)
    assert_match(/active_admin/, response.body)
  end
end
