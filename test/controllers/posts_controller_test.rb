# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    Post.ensure_defaults!
    @post = Post.find_by!(preset_slug: "guide-promo")
  end

  test "index and filmstrip preview render" do
    get posts_url(account: @admin.id)
    assert_response :success
    assert_select "a[href=?]", post_path(@post, account: @admin.id)
    assert_select "li .flex > span[style*=background-image]", { minimum: 3 }

    get post_url(@post, account: @admin.id)
    assert_response :success
    assert_select "ol[aria-label=Scenes] > li", { minimum: 3 }
    assert_includes response.body, "Keep the facade clear"
    assert_select "form[action=?]", post_path(@post, account: @admin.id)
    assert_select "[data-controller=pick] button[aria-label='Source image']"
    assert_select "[data-controller=pick] input[type=hidden][name='post[source]']"

    get canvas_post_url(@post, account: @admin.id, scene: "overlay-10")
    assert_response :success
    assert_includes response.body, "Keep the facade clear"
  end

  test "studio nav lists media bank and posts" do
    get posts_url(account: @admin.id)
    assert_select "a[href=?]", media_banks_path(account: @admin.id), text: /Media bank/
    assert_select "a[href=?]", posts_path(account: @admin.id)
  end

  test "transition canvas shows simple fade" do
    get canvas_post_url(@post, account: @admin.id, scene: "transition-0")
    assert_response :success
    assert_includes response.body, "Simple fade"
  end

  test "update saves source and ordered rules" do
    media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, user: nil)
    patch post_url(@post, account: @admin.id), params: {
      post: { preset_slug: "guide-promo", source: media.id.to_s, rules: [ 12, 10 ] }
    }
    assert_redirected_to post_path(@post, account: @admin.id)
    @post.reload
    assert_equal [ 12, 10 ], @post.rules_list
    assert_equal media.id.to_s, @post.source
  end

  test "create and destroy" do
    media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, user: nil)
    assert_difference -> { Post.count }, 1 do
      post posts_url(account: @admin.id), params: {
        post: { preset_slug: "guide-promo", source: media.id.to_s, rules: [ 12 ] }
      }
    end
    created = Post.order(:id).last
    assert_equal media.id.to_s, created.source
    assert_redirected_to post_path(created, account: @admin.id)

    assert_difference -> { Post.count }, -1 do
      delete post_url(created, account: @admin.id)
    end
    assert_redirected_to posts_path(account: @admin.id)
  end

  test "render enqueues job" do
    media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, user: nil)
    media.file.attach(io: File.open(Rails.root.join("test/fixtures/files/logo.png")), filename: "logo.png", content_type: "image/png")
    @post.update!(source: media.id.to_s)
    @post.seed_demo_frames!

    assert_enqueued_with(job: PostRenderJob) do
      post render_post_url(@post, account: @admin.id)
    end
    assert_redirected_to post_path(@post, account: @admin.id)
    assert_equal "pending", PostRender.last.status
  end

end
