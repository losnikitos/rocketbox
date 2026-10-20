# frozen_string_literal: true

require "test_helper"

class SortInboxMediaTest < ActiveSupport::TestCase
  setup { @original_chat = RubyLLM.method(:chat) }
  teardown { RubyLLM.define_singleton_method(:chat, @original_chat) }

  test "classify picks a folder from the given list" do
    asked = stub_chat { { "folder" => "customer" } }
    media = users(:lazaro_nixon).library_media.create!(kind: "photo", folder: folders(:inbox),
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    folders = [ folders(:customer), folders(:misc) ]

    assert_equal folders(:customer), SortInboxMedia.classify(media, folders:)
    schema, message, = asked.sole
    assert_equal %w[customer misc], schema.dig(:properties, :folder, :enum)
    assert_includes message, "- customer: Customer"
  end

  test "classify raises when the model fails" do
    stub_chat { raise RubyLLM::Error, "boom" }
    media = users(:lazaro_nixon).library_media.create!(kind: "photo", folder: folders(:inbox),
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })

    assert_raises(RubyLLM::Error) { SortInboxMedia.classify(media, folders: [ folders(:misc) ]) }
  end

  private

    def stub_chat(&reply)
      asked = []
      chat = Object.new
      chat.define_singleton_method(:with_schema) { |schema| asked << [ schema ] and self }
      chat.define_singleton_method(:ask) { |message, with:| asked.last.push(message, with) and Struct.new(:parsed).new(reply.call) }
      RubyLLM.define_singleton_method(:chat) { |**| chat }
      asked
    end
end
