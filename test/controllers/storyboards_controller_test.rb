# frozen_string_literal: true

require "test_helper"

class StoryboardsControllerTest < ActionDispatch::IntegrationTest
  setup { @admin = sign_in_as(users(:admin_user)) }

  test "index and scene preview render" do
    get storyboards_url(account: @admin.id)
    assert_response :success
    assert_select "a[href=?]", storyboard_path("guide-promo", account: @admin.id)

    get storyboard_url("guide-promo", account: @admin.id, scene: "overlay-10")
    assert_response :success
    assert_select "iframe[name=storyboard_preview]"
    assert_select "nav[aria-label=Scenes] a[aria-current=page][title=?]", "Overlay · rule #10"
    assert_select "form[action=?]", settings_storyboard_path("guide-promo", account: @admin.id)

    get canvas_storyboard_url("guide-promo", account: @admin.id, scene: "overlay-10")
    assert_response :success
    assert_includes response.body, "Keep the facade clear"
  end

  test "studio nav lists media bank and storyboard" do
    get storyboards_url(account: @admin.id)
    assert_select "a[href=?]", media_banks_path(account: @admin.id), text: /Media bank/
    assert_select "a[href=?]", storyboards_path(account: @admin.id)
  end

  test "transition canvas shows simple fade, png only for renderable scenes" do
    get canvas_storyboard_url("guide-promo", account: @admin.id, scene: "transition-0")
    assert_response :success
    assert_includes response.body, "Simple fade"

    get storyboard_url("guide-promo", format: :png, account: @admin.id, scene: "transition-0")
    assert_response :bad_request
  end

  test "settings save videos source rules and shared CTA" do
    board = Storyboard.find("guide-promo")
    patch settings_storyboard_url(board, account: @admin.id), params: {
      transition_type: "simple_fade",
      cta_text: "Tap guide",
      cta_href: "/guides/barbershop",
      overlays: { "0" => { number: 10, text: "Keep the facade clear" }, "1" => { number: 12, text: "Use warm light" } },
      videos: {
        "0" => { source: "/guides/barbershop/cluttered.jpg", rules: [ 10 ], afters: [ "/guides/barbershop/clean.jpg" ] }
      }
    }
    assert_redirected_to storyboard_path(board, account: @admin.id)

    settings = StoryboardSetting.find_by!(storyboard_slug: "guide-promo")
    assert_equal "Tap guide", settings.cta_text
    assert_equal [ 10 ], settings.videos.first["rules"].map(&:to_i)
    assert_equal "/guides/barbershop/cluttered.jpg", settings.videos.first["source"]
  end

  test "render enqueues job for a video" do
    board = Storyboard.find("guide-promo")
    StoryboardSetting.for(board).tap { it.assign_attributes(board.default_settings) }.save!

    assert_enqueued_with(job: StoryboardRenderJob) do
      post render_storyboard_url(board, account: @admin.id), params: { video: 0 }
    end
    assert_redirected_to storyboard_path(board, video: 0, account: @admin.id)
    assert_equal "pending", StoryboardRender.last.status
  end

  test "png is a screenshot of an overlay scene" do
    Ferrum::Browser.new.quit rescue skip("Chrome not available")

    get storyboard_url("guide-promo", format: :png, account: @admin.id, scene: "v0")
    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b)
  end
end
