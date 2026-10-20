# frozen_string_literal: true

require "test_helper"

class WhatsappOnboardingTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(whatsapp_phone: "15551234567")
    @sent = sent = []
    @original_text = WhatsappCloud.method(:send_text)
    @original_cta = WhatsappCloud.method(:send_cta_url)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body]; true }
    WhatsappCloud.define_singleton_method(:send_cta_url) { |**_| true }
  end

  teardown do
    WhatsappCloud.define_singleton_method(:send_text, @original_text)
    WhatsappCloud.define_singleton_method(:send_cta_url, @original_cta)
  end

  test "card_processed asks for logo when photobank has none" do
    @user.update!(whatsapp_pending_question: "processing_business_card")

    WhatsappOnboarding.card_processed!(@user)

    assert_equal "logo", @user.reload.whatsapp_pending_question
    assert_includes @sent, WhatsappOnboarding::MESSAGES["logo"]
  end

  test "card_processed asks for instagram when a logo media exists" do
    logo = @user.library_media.create!(kind: "photo", folder: Folder.logo)
    logo.file.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png")
    @user.update!(whatsapp_pending_question: "processing_business_card")

    WhatsappOnboarding.card_processed!(@user)

    assert_equal "instagram", @user.reload.whatsapp_pending_question
  end

  test "card_processed is a no-op when not processing a card" do
    @user.update!(whatsapp_pending_question: "brand_voice")

    WhatsappOnboarding.card_processed!(@user)

    assert_equal "brand_voice", @user.reload.whatsapp_pending_question
    assert_empty @sent
  end
end
