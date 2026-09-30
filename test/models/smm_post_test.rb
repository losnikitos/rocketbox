# frozen_string_literal: true

require "test_helper"

class SmmPostTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @media = LibraryMedia.create!(
      telegram_file_id: "f-model",
      telegram_file_unique_id: "u-model-media",
      kind: "photo",
      user: @user
    )
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "publishable when ready with a slide" do
    post = @user.smm_posts.new(status: "ready")
    post.smm_post_media_items.build(library_media: @media, position: 0)
    post.save!
    assert_not post.publishable?

    post.smm_slides.create!(media: { io: StringIO.new("v"), filename: "r.mp4", content_type: "video/mp4" })
    assert post.publishable?
    assert post.smm_slides.first.video?
  end

  test "a multi-slide post is a carousel" do
    post = @user.smm_posts.new(format: "post")
    2.times { post.smm_slides.build }
    assert post.carousel?
    post.format = "story"
    assert_not post.carousel?
  end
end
