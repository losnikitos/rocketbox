# frozen_string_literal: true

require "test_helper"

class GenerateMediaTest < ActiveSupport::TestCase
  setup do
    @generation = MediaGeneration.create!(
      model: "grok-imagine-image-2.0",
      prompt: "a clean fade",
      user: users(:admin_user)
    )
  end

  test "attaches image and marks succeeded" do
    bytes = "generated-image-bytes"
    service = GenerateMedia.new(generation: @generation)
    service.define_singleton_method(:connection) do
      response = Struct.new(:success?, :body, :status).new(
        true,
        { "data" => [ { "b64_json" => Base64.strict_encode64(bytes) } ] },
        200
      )
      conn = Object.new
      conn.define_singleton_method(:post) { |*_args, &_| response }
      conn
    end
    service.define_singleton_method(:api_key) { "test-key" }

    result = service.call
    assert result.succeeded?
    assert result.file.attached?
    assert_equal bytes, result.file.download
  end

  test "marks failed on API error" do
    service = GenerateMedia.new(generation: @generation)
    service.define_singleton_method(:connection) do
      response = Struct.new(:success?, :body, :status).new(
        false,
        { "error" => { "message" => "bad prompt" } },
        400
      )
      conn = Object.new
      conn.define_singleton_method(:post) { |*_args, &_| response }
      conn
    end
    service.define_singleton_method(:api_key) { "test-key" }

    error = assert_raises(GenerateMedia::Error) { service.call }
    assert_match(/bad prompt/, error.message)
    assert @generation.reload.failed?
    assert_equal "bad prompt", @generation.error_message
  end
end
