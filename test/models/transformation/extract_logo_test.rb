# frozen_string_literal: true

require "test_helper"

class Transformation::ExtractLogoTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @media = @user.library_media.create!(kind: "photo", folder: folders(:business_card))
    @media.file.attach(io: file_fixture("logo.png").open, filename: "card.png", content_type: "image/png")
    @transformation = Transformation.create!(name: "Extract logo", kind: "extract_logo",
      body: Transformation::ExtractLogo::DEFAULT_BODY)
    @original_chat = RubyLLM.method(:chat)
    @original_paint = RubyLLM.method(:paint)
  end

  teardown do
    RubyLLM.define_singleton_method(:chat, @original_chat)
    RubyLLM.define_singleton_method(:paint, @original_paint)
  end

  test "paints a logo into the output folder when the card has one" do
    stub_has_logo!(true)
    RubyLLM.define_singleton_method(:paint) do |*_, **_|
      RubyLLM::Image.new(data: Base64.strict_encode64("logo-bytes"), usage: { "cost" => 0.02 })
    end

    run = @transformation.run!(items: [ @media ], folder: Folder.logo, user: @user)
    run.run!

    assert run.reload.complete?
    assert_equal "logo-bytes", run.generated_media.file.download
    assert_equal Folder.logo, run.generated_media.folder
  end

  test "fails when the card has no logo" do
    stub_has_logo!(false)

    run = @transformation.run!(items: [ @media ], folder: Folder.logo, user: @user)
    run.run!

    assert run.reload.failed?
    assert_match(/No logo found/, run.error)
    assert_not @user.logo?
  end

  private

    def stub_has_logo!(value)
      cost = Struct.new(:total).new(0.01)
      reply = Struct.new(:parsed).new({ "has_logo" => value })
      chat = Object.new
      chat.define_singleton_method(:with_schema) { |_| chat }
      chat.define_singleton_method(:ask) { |*_, **_| reply }
      chat.define_singleton_method(:cost) { cost }
      RubyLLM.define_singleton_method(:chat) { |**_| chat }
    end
end

