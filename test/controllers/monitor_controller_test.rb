# frozen_string_literal: true

require "test_helper"

class MonitorControllerTest < ActionDispatch::IntegrationTest
  test "admin sees onboarding checklist for selected customer" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    patch account_selection_url, params: { user_id: customer.id }
    get monitor_onboarding_url

    assert_response :success
    assert_select "a[href=?]", sign_up_whatsapp_path, text: "WhatsApp code issued"
    assert_select "li", text: /447000000000/
  end

  test "admin resets whatsapp for selected customer" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000", whatsapp_connect_code: "abc123")
    patch account_selection_url, params: { user_id: customer.id }

    post monitor_onboarding_reset_url(step: "whatsapp")

    assert_redirected_to monitor_onboarding_url
    customer.reload
    assert_nil customer.whatsapp_phone
    assert_nil customer.whatsapp_connect_code
  end

  test "admin cannot delete themselves" do
    admin = sign_in_as(users(:admin_user))

    assert_no_difference("User.count") { post monitor_onboarding_reset_url(step: "user") }
    assert User.exists?(admin.id)
  end

  test "admin can open guarded signup screens without a draft" do
    admin = sign_in_as(users(:admin_user))
    admin.update!(whatsapp_phone: "447000000000")
    original = WhatsappCloud.method(:display_phone)
    WhatsappCloud.define_singleton_method(:display_phone) { "447451273884" }

    get sign_up_email_url
    assert_response :success
    get sign_up_email_code_url
    assert_response :success
    get sign_up_whatsapp_url
    assert_response :success
  ensure
    WhatsappCloud.define_singleton_method(:display_phone, original)
  end

  test "whatsapp connect code is issued to the selected customer" do
    admin = sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: nil, whatsapp_connect_code: nil)
    patch account_selection_url, params: { user_id: customer.id }

    get sign_up_whatsapp_url

    assert_response :success
    assert customer.reload.whatsapp_connect_code.present?
    assert_nil admin.reload.whatsapp_connect_code
  end

  test "non-admin is redirected" do
    sign_in_as(users(:lazaro_nixon))
    get monitor_onboarding_url

    assert_redirected_to root_url
  end
end
