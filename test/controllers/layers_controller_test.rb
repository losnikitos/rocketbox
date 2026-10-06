# frozen_string_literal: true

require "test_helper"

class LayersControllerTest < ActionDispatch::IntegrationTest
  setup { @admin = sign_in_as(users(:admin_user)) }

  test "index, preview and canvas render the template with inputs" do
    get layers_url(account: @admin.id)
    assert_select "a[href=?]", layer_path("fully-booked", account: @admin.id)

    get layer_url("fully-booked", account: @admin.id)
    assert_select "iframe[name=layer_preview]"
    assert_select "input[name=headline][value=?]", "Fully Booked"

    get canvas_layer_url("fully-booked", account: @admin.id, headline: "Closed today", date: "2026-10-04")
    assert_response :success
    assert_includes response.body, "Closed today"
    assert_includes response.body, "Sun, Oct 4"

    get canvas_layer_url("fully-booked", account: @admin.id, date: "nope")
    assert_includes response.body, Date.tomorrow.strftime("%a, %b %-d")
  end

  test "color fields accept only hex colors" do
    get canvas_layer_url("fully-booked-color", account: @admin.id, accent: "#ff0000", panel: "red;background:url(x)")
    assert_includes response.body, "--accent: #ff0000; --panel: #18181b"

    get layer_url("fully-booked-color", account: @admin.id)
    assert_select "input[type=color][name=accent][value=?]", "#ebcb9f"
  end

  test "review photo accepts only https urls" do
    get canvas_layer_url("review", account: @admin.id, name: "Sam K.", photo: "https://example.com/sam.jpg")
    assert_select "img[src=?]", "https://example.com/sam.jpg"
    assert_includes response.body, "Sam K."

    get canvas_layer_url("review", account: @admin.id, photo: "javascript:alert(1)")
    assert_select "img", 0
  end

  test "welcome shows its first lines and keeps the rest's space" do
    get canvas_layer_url("welcome", account: @admin.id, lines: "2")
    assert_select "span.block:not(.invisible)", text: /\A(Welcome|To)\z/, count: 2
    assert_select "span.invisible", text: /\A(Wick Lane|Barbershop)\z/, count: 2
  end

  test "png is a transparent screenshot of the canvas" do
    Ferrum::Browser.new.quit rescue skip("Chrome not available")

    get layer_url("fully-booked", format: :png, account: @admin.id)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b)
  end
end
