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
    original = Xai.method(:edit_image)
    Xai.define_singleton_method(:edit_image) { |prompt:, blob:| improved_bytes }

    assert_difference -> { LibraryMedia.count }, 1 do
      result = ImproveLibraryMedia.call(media: @media)
      assert result.file.attached?
      assert_equal @user, result.user
      assert_equal "photo", result.kind
      assert result.telegram_file_unique_id.start_with?("ai-")
      assert_equal improved_bytes, result.file.download
    end
  ensure
    Xai.define_singleton_method(:edit_image, original)
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
