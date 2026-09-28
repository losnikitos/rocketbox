# frozen_string_literal: true

require "test_helper"

class Accounts::OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sent = sent = []
    @original_send = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }
  end

  teardown do
    WhatsappCloud.define_singleton_method(:send_text, @original_send)
  end

  test "admin sees onboarding checklist for selected customer" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000", business_name: nil)
    patch account_selection_url, params: { user_id: customer.id }
    get onboarding_url

    assert_response :success
    assert_select "li", text: /\+447000000000/
    assert_select "form[action=?]", onboarding_ask_path(field: "business_name")
    assert_select "form[action=?]", onboarding_dashboard_link_path
  end

  test "ask in chat sends the question and the reply target is recorded" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    patch account_selection_url, params: { user_id: customer.id }

    post onboarding_ask_url(field: "business_name")

    assert_redirected_to onboarding_url
    assert_equal "business_name", customer.reload.whatsapp_pending_question
    assert_equal [ { phone_number_id: WhatsappCloud.phone_number_id, to: "447000000000", body: "What is your business name?" } ], @sent
  end

  test "media step shows count and previews, and asks for that media in chat" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    customer.library_media.create!(kind: "photo", media_type: "interior",
      file: { io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg" })
    patch account_selection_url, params: { user_id: customer.id }

    get onboarding_url
    assert_select "li", text: /Interior/, count: 0

    get onboarding_url(tab: "media")
    assert_select "li", text: /Interior\s+1 file/
    assert_select "li img[alt=photo]"

    post onboarding_ask_url(field: "interior")
    assert_redirected_to onboarding_url(tab: "media")
    assert_equal "interior", customer.reload.whatsapp_pending_question
    assert_equal "Send a photo of your interior 📸", @sent.sole[:body]
  end

  test "dashboard link logs the customer in once" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    patch account_selection_url, params: { user_id: customer.id }

    post onboarding_dashboard_link_url
    url = @sent.sole[:body][%r{https?://\S+}]
    delete sign_out_url

    assert_difference -> { customer.sessions.count }, 1 do
      get url
    end
    assert_redirected_to app_url

    delete sign_out_url
    get url
    assert_redirected_to sign_in_url
  end

  test "instagram ask sends a login link that lands on instagram authorize" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    patch account_selection_url, params: { user_id: customer.id }

    post onboarding_ask_url(field: "instagram")
    url = @sent.sole[:body][%r{https?://\S+}]
    delete sign_out_url

    get url
    assert_redirected_to profile_instagram_authorize_url
  end

  test "admin resets whatsapp for selected customer" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000", whatsapp_pending_question: "name")
    patch account_selection_url, params: { user_id: customer.id }

    post onboarding_reset_url(step: "whatsapp")

    assert_redirected_to onboarding_url
    customer.reload
    assert_nil customer.whatsapp_phone
    assert_nil customer.whatsapp_pending_question
  end

  test "admin cannot delete themselves" do
    admin = sign_in_as(users(:admin_user))

    assert_no_difference("User.count") { post onboarding_reset_url(step: "user") }
    assert User.exists?(admin.id)
  end

  test "non-admin is redirected" do
    sign_in_as(users(:lazaro_nixon))
    get onboarding_url

    assert_redirected_to root_url
  end
end
