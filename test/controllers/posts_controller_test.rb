# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    Post.ensure_defaults!
    @post = Post.find_by!(storyboard_slug: "guide-promo")
  end

  test "index and scene preview render" do
    get posts_url(account: @admin.id)
    assert_response :success
    assert_select "a[href=?]", post_path(@post, account: @admin.id)

    get post_url(@post, account: @admin.id, scene: "overlay-10")
    assert_response :success
    assert_select "iframe[name=post_preview]"
    assert_select "nav[aria-label=Scenes] a[aria-current=page][title=?]", "Overlay · rule #10"
    assert_select "form[action=?]", post_path(@post, account: @admin.id)

    get canvas_post_url(@post, account: @admin.id, scene: "overlay-10")
    assert_response :success
    assert_includes response.body, "Keep the facade clear"
  end

  test "studio nav lists media bank and posts" do
    get posts_url(account: @admin.id)
    assert_select "a[href=?]", media_banks_path(account: @admin.id), text: /Media bank/
    assert_select "a[href=?]", posts_path(account: @admin.id)
  end

  test "transition canvas shows simple fade, png only for renderable scenes" do
    get canvas_post_url(@post, account: @admin.id, scene: "transition-0")
    assert_response :success
    assert_includes response.body, "Simple fade"

    get post_url(@post, format: :png, account: @admin.id, scene: "transition-0")
    assert_response :bad_request
  end

  test "update saves source and rules" do
    patch post_url(@post, account: @admin.id), params: {
      post: { name: "Guide promo", storyboard_slug: "guide-promo", source: "/guides/barbershop/cluttered.jpg", rules: [ 10 ] }
    }
    assert_redirected_to post_path(@post, account: @admin.id)
    assert_equal [ 10 ], @post.reload.rules_list
  end

  test "create and destroy" do
    assert_difference -> { Post.count }, 1 do
      post posts_url(account: @admin.id), params: {
        post: { name: "Custom", storyboard_slug: "guide-promo", source: "/guides/barbershop/warm.jpg", rules: [ 12 ] }
      }
    end
    created = Post.order(:id).last
    assert_redirected_to post_path(created, account: @admin.id)

    assert_difference -> { Post.count }, -1 do
      delete post_url(created, account: @admin.id)
    end
    assert_redirected_to posts_path(account: @admin.id)
  end

  test "render enqueues job" do
    assert_enqueued_with(job: PostRenderJob) do
      post render_post_url(@post, account: @admin.id)
    end
    assert_redirected_to post_path(@post, account: @admin.id)
    assert_equal "pending", PostRender.last.status
  end

  test "png is a screenshot of an overlay scene" do
    Ferrum::Browser.new.quit rescue skip("Chrome not available")

    get post_url(@post, format: :png, account: @admin.id, scene: "v0")
    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b)
  end
end
