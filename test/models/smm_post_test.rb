# frozen_string_literal: true

require "test_helper"

class SmmPostTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @prompt = prompts(:cinematic)
    @media = LibraryMedia.create!(
      telegram_file_id: "f-model",
      telegram_file_unique_id: "u-model-media",
      kind: "photo",
      user: @user
    )
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "requires at least one image" do
    post = @user.smm_posts.new(prompt: @prompt, status: "draft")
    assert_not post.valid?
    assert_match(/at least one image/, post.errors[:base].join)
  end

  test "rejects videos as source media" do
    video = LibraryMedia.create!(
      telegram_file_id: "f-vid",
      telegram_file_unique_id: "u-vid-model",
      kind: "video",
      user: @user
    )
    video.file.attach(io: StringIO.new("vid"), filename: "a.mp4", content_type: "video/mp4")

    post = @user.smm_posts.new(prompt: @prompt, status: "draft")
    post.smm_post_media_items.build(library_media: video, position: 0)
    assert_not post.valid?
    assert_match(/Only images/, post.errors[:base].join)
  end

  test "publishable when ready with attached video" do
    post = @user.smm_posts.new(prompt: @prompt, status: "ready")
    post.smm_post_media_items.build(library_media: @media, position: 0)
    post.save!
    assert_not post.publishable?

    post.generated_video.attach(io: StringIO.new("v"), filename: "r.mp4", content_type: "video/mp4")
    assert post.publishable?
  end
end
