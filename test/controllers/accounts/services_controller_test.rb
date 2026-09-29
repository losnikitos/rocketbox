# frozen_string_literal: true

require "test_helper"

class Accounts::ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "creates, edits and removes services, only your own" do
    get services_url
    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", services_path, text: /Services/

    assert_no_difference -> { Service.count } do
      post services_url, params: { service: { name: "", price: "£25" } }
    end
    assert_response :unprocessable_entity

    post services_url, params: { service: { name: "Skin fade", price: "£25", duration: "45 min" } }
    assert_redirected_to services_url
    service = @user.services.last
    get services_url
    assert_select "##{dom_id(service)}", text: /Skin fade.*£25 · 45 min/m

    get edit_service_url(service)
    assert_response :success
    patch service_url(service), params: { service: { name: "", description: "x" } }
    assert_response :unprocessable_entity
    patch service_url(service), params: { service: { name: "Beard trim", description: "Hot towel" } }
    assert_redirected_to services_url
    assert_equal [ "Beard trim", "Hot towel" ], service.reload.values_at(:name, :description)

    admin = sign_in_as(users(:admin_user))
    get edit_service_url(service, account: admin.id)
    assert_response :not_found
    delete service_url(service)
    assert_response :not_found

    sign_in_as(@user)
    assert_difference -> { Service.count } => -1 do
      delete service_url(service)
    end
    assert_redirected_to services_url
  end
end
