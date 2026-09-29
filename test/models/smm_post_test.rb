# frozen_string_literal: true

require "test_helper"

class SmmPostTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @recipe = recipes(:cinematic)
    @media = LibraryMedia.create!(
      telegram_file_id: "f-model",
      telegram_file_unique_id: "u-model-media",
      kind: "photo",
      user: @user
    )
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "requires at least one image" do
    post = @user.smm_posts.new(recipe: @recipe, status: "draft")
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

    post = @user.smm_posts.new(recipe: @recipe, status: "draft")
    post.smm_post_media_items.build(library_media: video, position: 0)
    assert_not post.valid?
    assert_match(/Only images/, post.errors[:base].join)
  end

  test "publishable when ready with a slide" do
    post = @user.smm_posts.new(recipe: @recipe, status: "ready")
    post.smm_post_media_items.build(library_media: @media, position: 0)
    post.save!
    assert_not post.publishable?

    post.smm_slides.create!(media: { io: StringIO.new("v"), filename: "r.mp4", content_type: "video/mp4" })
    assert post.publishable?
    assert post.smm_slides.first.video?
  end

  test "requires the recipe's number of inputs" do
    recipe = Recipe.create!(name: "Story", workflow: "BankHolidayStory")
    post = @user.smm_posts.new(recipe:, status: "draft")
    post.smm_post_media_items.build(library_media: @media, position: 0)
    assert_not post.valid?
    assert_match(/needs exactly 2 images/, post.errors[:base].join)
  end

  test "a multi-slide post is a carousel" do
    post = @user.smm_posts.new(recipe: @recipe, format: "post")
    2.times { post.smm_slides.build }
    assert post.carousel?
    post.format = "story"
    assert_not post.carousel?
  end
end
