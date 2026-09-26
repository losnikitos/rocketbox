# frozen_string_literal: true

require "test_helper"

class Accounts::LibraryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show library uploads" do
    get library_uploads_url
    assert_response :success
    assert_select "h1", "Library"
    assert_select "nav[aria-label='Primary']"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", library_uploads_path, text: /Library/
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", library_uploads_path, text: "Uploads"
    assert_select "nav[aria-label='Secondary'] a", text: "Reels", count: 0
    assert_select "nav[aria-label='Primary'] a[href=?]", profile_settings_path, text: "Profile"
    assert_select "button[popovertarget='use-cases-menu']", count: 0
  end

  test "shows selectable story images without publish or improve" do
    media = LibraryMedia.create!(
      telegram_file_id: "f3",
      telegram_file_unique_id: "u3-library-btn",
      kind: "photo",
      user: @user
    )
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    get library_uploads_url
    assert_response :success
    assert_select "form[action=?]", new_smm_post_path
    assert_select "input[data-library-select-target=?]", "checkbox"
    assert_select "button", text: "Publish as Instagram story", count: 0
    assert_select "button", text: "Improve with AI", count: 0
  end

  test "requires sign in" do
    delete session_url(@user.sessions.last)
    get library_uploads_url
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

    get library_uploads_url
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

    get library_uploads_url
    assert_response :success
    assert_select "[title='Admin actions']", count: 0
  end

  test "app root redirects to library uploads" do
    get "/app"
    assert_redirected_to "/app/library/uploads"
  end
end
