# frozen_string_literal: true

require "test_helper"

class Transformation::UpdateBusinessTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(business_name: "Old", phone: nil, homepage_url: nil)
    @media = @user.library_media.create!(kind: "photo", folder: folders(:business_card))
    @media.file.attach(io: file_fixture("logo.png").open, filename: "card.png", content_type: "image/png")
    @transformation = Transformation.create!(name: "Update business", kind: "update_business",
      body: Transformation::UpdateBusiness::DEFAULT_BODY)
    @original_chat = RubyLLM.method(:chat)
  end

  teardown do
    RubyLLM.define_singleton_method(:chat, @original_chat)
  end

  test "writes non-blank fields onto the media owner and returns JSON" do
    stub_schema_chat!("business_name" => " Fade Co ", "phone" => "+1 555", "person_name" => nil,
      "address" => "", "website" => "https://fade.co", "business_description" => nil)

    run = @transformation.run!(items: [ @media ], folder: Folder.prompts, user: @user)
    run.run!

    assert run.reload.complete?
    @user.reload
    assert_equal "Fade Co", @user.business_name
    assert_equal "+1 555", @user.phone
    assert_equal "https://fade.co", @user.homepage_url
    assert_includes run.result.body, "Fade Co"
  end

  test "skips update when every field is blank" do
    stub_schema_chat!(Transformation::UpdateBusiness::FIELDS.keys.index_with { nil })

    run = @transformation.run!(items: [ @media ], folder: Folder.prompts, user: @user)
    run.run!

    assert_equal "Old", @user.reload.business_name
    assert run.reload.complete?
  end

  private

    def stub_schema_chat!(fields)
      cost = Struct.new(:total).new(0.01)
      reply = Struct.new(:parsed).new(fields)
      chat = Object.new
      chat.define_singleton_method(:with_schema) { |_| chat }
      chat.define_singleton_method(:ask) { |*_, **_| reply }
      chat.define_singleton_method(:cost) { cost }
      RubyLLM.define_singleton_method(:chat) { |**_| chat }
    end
end

