# frozen_string_literal: true

require "test_helper"

class Accounts::BusinessControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show business" do
    get business_url
    assert_response :success
    assert_select "h2", "Business"
    assert_select "form[action=?]", business_path
    assert_select "input[name='user[homepage_url]']"
  end

  test "should update business name, homepage, and hours" do
    patch business_url, params: {
      user: {
        business_name: "Ada Cuts",
        homepage_url: "https://adacuts.example",
        business_hours: "Mon–Fri 9–6"
      }
    }

    assert_redirected_to business_url
    assert_equal "Business updated.", flash[:notice]

    @user.reload
    assert_equal "Ada Cuts", @user.business_name
    assert_equal "https://adacuts.example", @user.homepage_url
    assert_equal "Mon–Fri 9–6", @user.business_hours
  end

  test "autosave update returns ok without redirect" do
    patch business_url,
      params: { user: { business_name: "Ada Cuts", homepage_url: "https://adacuts.example", business_hours: "Mon–Fri 9–6" } },
      headers: { "X-Autosave" => "1", "Accept" => "application/json" }

    assert_response :ok
    assert_equal "Ada Cuts", @user.reload.business_name
    assert_equal "https://adacuts.example", @user.homepage_url
  end

  test "should attach logo" do
    patch business_url, params: {
      user: {
        business_name: "Ada Cuts",
        logo: fixture_file_upload("logo.png", "image/png")
      }
    }

    assert_redirected_to business_url
    assert @user.reload.logo.attached?
  end
end
