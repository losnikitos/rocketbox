# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show library uploads by default" do
    get library_url
    assert_response :success
    assert_select "h1", "Uploads"
    assert_select "nav[aria-label='Library folders']"
    assert_select "a[href=?][aria-current='page']", library_path(folder: "uploads"), text: "Uploads"
    assert_select "a[href=?]", library_path(folder: "stories"), text: "Stories"
    assert_select "a[href=?]", library_path(folder: "reels"), text: "Reels"
    assert_select "nav[aria-label='Profile sections']", count: 0
    assert_select "a[href=?]", profile_settings_path, text: "My profile"
    assert_select "button[popovertarget='use-cases-menu']", count: 0
  end

  test "stories and reels folders are empty" do
    get library_url(folder: "stories")
    assert_response :success
    assert_select "h1", "Stories"
    assert_select "a[href=?][aria-current='page']", library_path(folder: "stories"), text: "Stories"

    get library_url(folder: "reels")
    assert_response :success
    assert_select "h1", "Reels"
    assert_select "a[href=?][aria-current='page']", library_path(folder: "reels"), text: "Reels"
  end

  test "shows publish button for story media" do
    media = LibraryMedia.create!(
      telegram_file_id: "f3",
      telegram_file_unique_id: "u3-library-btn",
      kind: "photo",
      user: @user
    )
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    get library_url
    assert_response :success
    assert_select "form[action=?]", library_instagram_story_path(media)
    assert_select "form[action=?]", library_improve_path(media)
  end

  test "requires sign in" do
    delete session_url(@user.sessions.last)
    get library_url
    assert_redirected_to sign_in_url
  end

  test "admin sees admin and remove links on media" do
    admin = sign_in_as(users(:admin_user))
    media = LibraryMedia.create!(
      telegram_file_id: "f-admin",
      telegram_file_unique_id: "u-admin-library",
      kind: "photo",
      user: admin
    )
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    get library_url
    assert_response :success
    assert_select "[title='Admin actions']"
    assert_select "a[href=?]", admin_library_media_path(media), text: "Admin"
    assert_select "a[href=?][data-turbo-method=?]", library_media_path(media), "delete", text: "Remove"
  end

  test "non-admin does not see admin link menu" do
    media = LibraryMedia.create!(
      telegram_file_id: "f-user",
      telegram_file_unique_id: "u-user-library",
      kind: "photo",
      user: @user
    )
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    get library_url
    assert_response :success
    assert_select "[title='Admin actions']", count: 0
  end

  test "app root redirects to library" do
    get "/app"
    assert_redirected_to "/app/library"
  end
end
