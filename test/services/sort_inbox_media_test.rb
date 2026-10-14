# frozen_string_literal: true

require "test_helper"

class SortInboxMediaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { @original_chat = RubyLLM.method(:chat) }
  teardown { RubyLLM.define_singleton_method(:chat, @original_chat) }

  test "a photo landing in the inbox root moves to the subfolder the model picks, offered every subfolder" do
    asked = stub_chat { { "folder" => "interior" } }

    media = perform_enqueued_jobs(only: AutorunWorkflowsJob) { land }

    assert_equal folders(:interior), media.reload.folder
    schema, message, with = asked.sole
    assert_equal folders(:inbox).children.map(&:slug), schema.dig(:properties, :folder, :enum)
    assert_includes message, "- misc: Misc"
    assert_equal media.file.blob, with.blob
  end

  test "it stays in the inbox root when the model fails" do
    stub_chat { raise RubyLLM::Error, "boom" }

    media = perform_enqueued_jobs(only: AutorunWorkflowsJob) { land }

    assert_equal folders(:inbox), media.reload.folder
  end

  private

    def land
      users(:lazaro_nixon).library_media.create!(kind: "photo",
        file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    end

    # Collects each ask's schema, message and attachment; replies with what the block returns as the parsed reply.
    def stub_chat(&reply)
      asked = []
      chat = Object.new
      chat.define_singleton_method(:with_schema) { |schema| asked << [ schema ] and self }
      chat.define_singleton_method(:ask) { |message, with:| asked.last.push(message, with) and Struct.new(:parsed).new(reply.call) }
      RubyLLM.define_singleton_method(:chat) { |**| chat }
      asked
    end
end
