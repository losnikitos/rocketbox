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
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", smm_posts_path, text: /SMM/
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", smm_stories_path, text: "Stories"

    get smm_reels_url
    assert_response :success
    assert_select "h1", "SMM"
    assert_select "h2", "Reels"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", smm_reels_path, text: "Reels"
    assert_select "nav[aria-label='Secondary'] a[href=?]", smm_posts_path, text: "Posts"
  end

  test "smm root redirects to posts" do
    get "/app/smm"
    assert_redirected_to "/app/smm/posts"
  end
end
