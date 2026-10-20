# frozen_string_literal: true

require "test_helper"

class LoginLinkTest < ActiveSupport::TestCase
  setup do
    @sent = sent = []
    @original_cta = WhatsappCloud.method(:send_cta_url)
    WhatsappCloud.define_singleton_method(:send_cta_url) { |**args| sent << args }
  end

  teardown do
    WhatsappCloud.define_singleton_method(:send_cta_url, @original_cta)
  end

  test "returns error when user is nil" do
    result = LoginLink.new(user: nil).execute

    assert result[:error].present?
    assert_match(/No Rocketbox account linked/, result[:error])
  end

  test "sends CTA when user has whatsapp_phone" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")

    result = LoginLink.new(user:).execute

    assert result[:sent]
    assert_equal 1, @sent.size
    assert_match %r{/sign_in/whatsapp}, @sent.sole[:url]
    assert_equal "Open dashboard", @sent.sole[:display_text]
  end

  test "returns url when user has no whatsapp_phone" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: nil)

    result = LoginLink.new(user:).execute

    assert_match %r{/sign_in/whatsapp}, result[:url]
    assert_empty @sent
  end
end
