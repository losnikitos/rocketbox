# frozen_string_literal: true

require "test_helper"

class LibrariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show library" do
    get library_url
    assert_response :success
    assert_select "h1", "Library"
  end

  test "requires sign in" do
    delete session_url(@user.sessions.last)
    get library_url
    assert_redirected_to sign_in_url
  end
end
