# frozen_string_literal: true

require "test_helper"

class Accounts::OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sent = sent = []
    @original_send = WhatsappCloud.method(:send_text)
    @original_cta = WhatsappCloud.method(:send_cta_url)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }
    WhatsappCloud.define_singleton_method(:send_cta_url) { |**args| sent << args }
  end

  teardown do
    WhatsappCloud.define_singleton_method(:send_text, @original_send)
    WhatsappCloud.define_singleton_method(:send_cta_url, @original_cta)
  end

  test "admin sees onboarding checklist for selected customer" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000", business_name: nil)
    get onboarding_url(account: customer.id)

    assert_response :success
    assert_select "li", text: /\+447000000000/
    assert_select "form[action=?]", onboarding_ask_path(field: "business_card", account: customer.id)
    assert_select "form[action=?]", onboarding_dashboard_link_path(account: customer.id)
  end

  test "ask in chat sends the step message and the reply target is recorded" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    post onboarding_ask_url(field: "business_card", account: customer.id)

    assert_redirected_to onboarding_url(account: customer.id)
    assert_equal "business_card", customer.reload.whatsapp_pending_question
    assert_equal [ { phone_number_id: WhatsappCloud.phone_number_id, to: "447000000000", body: WhatsappOnboarding::MESSAGES["business_card"] } ], @sent
  end

  test "media step shows count and previews, and asks for that media in chat" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    customer.library_media.create!(kind: "photo", media_type: media_types(:interior),
      file: { io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg" })
    get onboarding_url(tab: "media", account: customer.id)
    assert_select "li", text: /Interior\b.*1 file/m
    assert_select "li img[alt=photo]"

    post onboarding_ask_url(field: "interior_front"), headers: { "Referer" => onboarding_url(tab: "media") }
    assert_redirected_to onboarding_url(tab: "media")
    assert_equal "interior_front", customer.reload.whatsapp_pending_question
    assert_equal WhatsappOnboarding::MESSAGES["interior_front"], @sent.sole[:body]
  end

  test "dashboard link logs the customer in once" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    post onboarding_dashboard_link_url(account: customer.id)
    url = @sent.sole[:url]
    delete sign_out_url

    assert_difference -> { customer.sessions.count }, 1 do
      get url
    end
    assert_redirected_to app_path

    delete sign_out_url
    get url
    assert_redirected_to sign_in_path
  end

  test "instagram ask sends a login link that lands on instagram authorize" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000")
    post onboarding_ask_url(field: "instagram", account: customer.id)
    url = @sent.sole[:url]
    delete sign_out_url

    get url
    assert_redirected_to profile_instagram_authorize_path
  end

  test "admin resets whatsapp for selected customer" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)
    customer.update!(whatsapp_phone: "447000000000", whatsapp_pending_question: "email")
    post onboarding_reset_url(step: "whatsapp", account: customer.id)

    assert_redirected_to onboarding_url(account: customer.id)
    customer.reload
    assert_nil customer.whatsapp_phone
    assert_nil customer.whatsapp_pending_question
  end

  test "admin cannot delete themselves" do
    admin = sign_in_as(users(:admin_user))

    assert_no_difference("User.count") { post onboarding_reset_url(step: "user") }
    assert User.exists?(admin.id)
  end

  test "non-admin sees own onboarding but not the admin page" do
    sign_in_as(users(:lazaro_nixon))

    get onboarding_url(tab: "media")
    assert_response :success
    assert_select "a[href=?]", admin_path, count: 0

    get admin_url
    assert_redirected_to root_url
  end

  test "admin sees meta links on admin page" do
    admin = sign_in_as(users(:admin_user))
    get admin_url(account: admin.id)

    assert_response :success
    assert_select "h2", "Meta"
  end
end
