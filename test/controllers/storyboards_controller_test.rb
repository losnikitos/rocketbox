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

    get canvas_storyboard_url("guide-promo", account: @admin.id, scene: "overlay-10")
    assert_response :success
    assert_includes response.body, "Keep the facade clear"
  end

  test "studio nav lists media bank and storyboard" do
    get storyboards_url(account: @admin.id)
    assert_select "a[href='/admin/media_bank']", text: /Media bank/
    assert_select "a[href=?]", storyboards_path(account: @admin.id)
  end

  test "transition canvas shows stub, png only for renderable scenes" do
    get canvas_storyboard_url("guide-promo", account: @admin.id, scene: "transition-v0-v1")
    assert_response :success
    assert_includes response.body, "Video transition · stub"

    get storyboard_url("guide-promo", format: :png, account: @admin.id, scene: "transition-v0-v1")
    assert_response :bad_request
  end

  test "png is a screenshot of an overlay scene" do
    Ferrum::Browser.new.quit rescue skip("Chrome not available")

    get storyboard_url("guide-promo", format: :png, account: @admin.id, scene: "v0")
    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b)
  end
end
