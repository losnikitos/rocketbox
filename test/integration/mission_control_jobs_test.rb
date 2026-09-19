require "test_helper"

class MissionControlJobsTest < ActionDispatch::IntegrationTest
  test "admin can open jobs dashboard" do
    sign_in_as(users(:admin_user))

    get "/jobs"
    assert_response :success
  end

  test "non-admin cannot open jobs dashboard" do
    sign_in_as(users(:lazaro_nixon))

    get "/jobs"
    assert_response :not_found
  end

  test "guest cannot open jobs dashboard" do
    get "/jobs"
    assert_response :not_found
  end
end
