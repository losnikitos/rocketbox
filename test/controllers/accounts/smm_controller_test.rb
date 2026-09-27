# frozen_string_literal: true

require "test_helper"

class Accounts::SmmControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:lazaro_nixon))
  end

  test "stories and reels are empty stubs under SMM" do
    get smm_stories_url
    assert_response :success
    assert_select "h1", "SMM"
    assert_select "h2", "Stories"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", smm_root_path, text: /SMM/
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", smm_stories_path, text: "Stories"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='false']", smm_root_path, text: "All"

    get smm_reels_url
    assert_response :success
    assert_select "h1", "SMM"
    assert_select "h2", "Reels"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", smm_reels_path, text: "Reels"
    assert_select "nav[aria-label='Secondary'] a[href=?]", smm_posts_path, text: "Posts"
  end

  test "smm root shows All tab with every post" do
    user = users(:lazaro_nixon)
    media = LibraryMedia.create!(telegram_file_id: "f-all", telegram_file_unique_id: "u-all", kind: "photo", user:)
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
    post_record = user.smm_posts.new(prompt: prompts(:cinematic), status: "draft")
    post_record.smm_post_media_items.build(library_media: media, position: 0)
    post_record.save!

    get smm_root_url
    assert_response :success
    assert_select "h2", "All"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", smm_root_path, text: "All"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='false']", smm_posts_path, text: "Posts"
    assert_select "nav[aria-label='Secondary'] span[aria-hidden='true']"
    assert_select "a[href=?]", smm_post_path(post_record)
  end
end
