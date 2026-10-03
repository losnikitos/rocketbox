# frozen_string_literal: true

require "test_helper"

class Accounts::PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @media = LibraryMedia.create!(
      telegram_file_id: "f-post",
      telegram_file_unique_id: "u-post-media",
      kind: "photo",
      user: @user
    )
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "show renders a post by its format" do
    post_record = create_ready_post!

    get instagram_post_url(post_record)
    assert_response :success
    assert_select "p", text: /Posts\s+\/\s+Reel/
    assert_select "button", text: /publish to Instagram/
  end

  test "publish enqueues instagram job when ready" do
    post_record = create_ready_post!

    assert_enqueued_with(job: PublishSmmPostJob, args: [ post_record.id ]) do
      post publish_instagram_post_url(post_record)
    end

    assert_redirected_to instagram_post_url(post_record)
  end

  test "publish rejects posts that are not ready" do
    post_record = build_draft_post!

    post publish_instagram_post_url(post_record)
    assert_redirected_to instagram_post_url(post_record)
    assert_match(/not ready/, flash[:alert])
  end

  test "index lists posts as media thumbnails" do
    post_record = create_ready_post!

    get instagram_posts_url
    assert_response :success
    assert_select "h1", "Posts"
    assert_select "h2", "All"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", instagram_posts_path, text: "Posts"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", instagram_posts_path, text: "All"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='false']", instagram_posts_path(kind: "posts"), text: "Posts"
    assert_select "a[href=?]", instagram_post_path(post_record)
    assert_select "a[href=?] video[muted][preload=metadata]:not([controls])", instagram_post_path(post_record)
    assert_select "a[href=?] span", instagram_post_path(post_record), text: "ready"
    assert_select "section h3", "Today"

    get instagram_posts_url(kind: "reels")
    assert_select "h2", "Reels"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", instagram_posts_path(kind: "reels"), text: "Reels"
    assert_select "a[href=?]", instagram_post_path(post_record)
  end

  test "kinds filter by post format" do
    post_record = create_ready_post!
    post_record.update!(format: "story")

    get instagram_posts_url(kind: "stories")
    assert_select "h2", "Stories"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", instagram_posts_path(kind: "stories"), text: "Stories"
    assert_select "a[href=?]", instagram_post_path(post_record)

    %w[reels posts].each do |kind|
      get instagram_posts_url(kind:)
      assert_select "p", text: /Nothing yet/
    end
  end

  test "non-admin cannot remove post" do
    post_record = build_draft_post!

    assert_no_difference -> { SmmPost.count } do
      delete instagram_post_url(post_record)
    end
    assert_redirected_to instagram_posts_url
  end

  test "admin sees menu and can remove post" do
    @user = sign_in_as(users(:admin_user))
    @media.update!(user: @user)
    post_record = build_draft_post!

    get instagram_posts_url(account: @user.id)
    assert_select "a[href=?]", admin_smm_post_path(post_record, account: @user.id)
    assert_select "a[href=?][data-turbo-method=delete]", instagram_post_path(post_record, account: @user.id)

    assert_difference -> { SmmPost.count }, -1 do
      delete instagram_post_url(post_record)
    end
    assert_redirected_to instagram_posts_url(account: @user.id)
    assert_equal "Post removed.", flash[:notice]
  end

  test "only admins see how a recipe post was generated" do
    post_record = create_ready_post!
    recipe = Recipe.create!(name: "Daily", body: "A day at work.", format: "story", media_type_ids: [ MediaType.create!(name: "Interior").id ])
    post_record.update_columns(recipe_id: recipe.id, prompt: "A day at work.", options: { "model" => "gpt-image-2", "aspect_ratio" => "9:16" })

    get instagram_post_url(post_record)
    assert_select "#generation", count: 0

    @user = sign_in_as(users(:admin_user))
    post_record.update_columns(user_id: @user.id)
    get instagram_post_url(post_record, account: @user.id)
    assert_select "#generation a[href=?]", edit_recipe_path(recipe, account: @user.id), text: "Daily"
    assert_select "#generation td", text: "gpt-image-2"
    assert_select "#generation td", text: "9:16"
    assert_select "#generation textarea[readonly]", text: "A day at work."
  end

  test "react saves thumbs up instantly" do
    post_record = create_ready_post!

    post react_instagram_post_url(post_record), params: { reaction: "up" }, as: :json
    assert_response :success
    assert_equal "up", post_record.reload.reaction
    assert_nil post_record.reaction_comment
  end

  test "react saves thumbs down with optional comment" do
    post_record = create_ready_post!

    post react_instagram_post_url(post_record), params: { reaction: "down" }, as: :json
    assert_response :success
    assert_equal "down", post_record.reload.reaction

    post react_instagram_post_url(post_record),
         params: { reaction: "down", reaction_comment: "Too dark" },
         as: :json
    assert_response :success
    assert_equal "Too dark", post_record.reload.reaction_comment
  end

  test "react rejects invalid reaction" do
    post_record = create_ready_post!

    post react_instagram_post_url(post_record), params: { reaction: "meh" }, as: :json
    assert_response :unprocessable_entity
  end

  test "react clears reaction when blank" do
    post_record = create_ready_post!
    post_record.update!(reaction: "up")

    post react_instagram_post_url(post_record), params: { reaction: "" }, as: :json
    assert_response :success
    assert_nil post_record.reload.reaction
  end

  private

    def build_draft_post!
      post_record = @user.smm_posts.new(status: "draft")
      post_record.smm_post_media_items.build(library_media: @media, position: 0)
      post_record.save!
      post_record
    end

    def create_ready_post!
      post_record = build_draft_post!
      post_record.update!(status: "ready")
      post_record.smm_slides.create!(media: { io: StringIO.new("fake-video"), filename: "reel.mp4", content_type: "video/mp4" })
      post_record
    end
end
