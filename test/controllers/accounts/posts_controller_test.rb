# frozen_string_literal: true

require "test_helper"

class Accounts::PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @recipe = recipes(:cinematic)
    @media = LibraryMedia.create!(
      telegram_file_id: "f-post",
      telegram_file_unique_id: "u-post-media",
      kind: "photo",
      user: @user
    )
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "new requires selected media" do
    get new_instagram_post_url
    assert_redirected_to library_uploads_url
    assert_match(/Select at least one image/, flash[:alert])
  end

  test "new shows selected media and recipes" do
    get new_instagram_post_url, params: { library_media_ids: [ @media.id ] }
    assert_response :success
    assert_select "h2", "Create Instagram post"
    assert_select "select[name=recipe_id]"
    assert_select "option", text: "#{@recipe.name} (Reel)"
  end

  test "create starts the recipe workflow" do
    assert_difference -> { SmmPost.count }, 1 do
      assert_enqueued_with(job: RunWorkflowJob) do
        post instagram_posts_url, params: {
          library_media_ids: [ @media.id ],
          recipe_id: @recipe.id,
          caption: "Fresh cut"
        }
      end
    end

    post_record = SmmPost.order(:id).last
    assert_redirected_to instagram_post_url(post_record)
    assert_equal "generating", post_record.status
    assert_equal "Fresh cut", post_record.caption
    assert_equal [ @media.id ], post_record.library_media.ids
    assert_equal %w[photos video reel], post_record.workflow_run.workflow_steps.map(&:key)

    get instagram_post_url(post_record)
    assert_response :success
    assert_select "article", count: 3
    assert_select "button", text: "Pause"
  end

  test "pause, resume and rerun control the workflow" do
    post_record = build_draft_post!
    run = WorkflowRun.start!(post_record)

    post pause_instagram_post_url(post_record)
    assert run.reload.paused?

    assert_enqueued_with(job: RunWorkflowJob, args: [ run.id ]) { post resume_instagram_post_url(post_record) }
    assert run.reload.running?

    run.fail!("boom")
    assert_enqueued_with(job: RunWorkflowJob, args: [ run.id ]) { post rerun_instagram_post_url(post_record, key: "video") }
    assert run.reload.running?
    assert_equal "generating", post_record.reload.status

    post rerun_instagram_post_url(post_record, key: "nope")
    assert_response :unprocessable_entity
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
      post_record = @user.smm_posts.new(recipe: @recipe, status: "draft")
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
