# frozen_string_literal: true

require "test_helper"

class ImproveLibraryMediaTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @media = LibraryMedia.create!(
      telegram_file_id: "f1",
      telegram_file_unique_id: "u1-improve-test",
      kind: "photo",
      user: @user
    )
    @media.file.attach(
      io: StringIO.new("fake-image"),
      filename: "shot.jpg",
      content_type: "image/jpeg"
    )
  end

  test "creates improved library media from xAI response" do
    improved_bytes = "improved-image-bytes"
    service = ImproveLibraryMedia.new(media: @media)
    service.define_singleton_method(:connection) do
      response = Struct.new(:success?, :body, :status).new(
        true,
        { "data" => [ { "b64_json" => Base64.strict_encode64(improved_bytes) } ] },
        200
      )
      conn = Object.new
      conn.define_singleton_method(:post) { |*_args, &_| response }
      conn
    end
    service.define_singleton_method(:api_key) { "test-key" }

    assert_difference -> { LibraryMedia.count }, 1 do
      result = service.call
      assert result.file.attached?
      assert_equal @user, result.user
      assert_equal "photo", result.kind
      assert result.telegram_file_unique_id.start_with?("ai-")
      assert_equal improved_bytes, result.file.download
    end
  end

  test "rejects non-images" do
    video = LibraryMedia.create!(
      telegram_file_id: "f-vid",
      telegram_file_unique_id: "u-vid-improve",
      kind: "video",
      user: @user
    )
    video.file.attach(
      io: StringIO.new("fake-video"),
      filename: "clip.mp4",
      content_type: "video/mp4"
    )

    error = assert_raises(ImproveLibraryMedia::Error) do
      ImproveLibraryMedia.call(media: video)
    end

    assert_match(/Only images/, error.message)
  end
end
