# frozen_string_literal: true

require "test_helper"

class LibrariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show library" do
    get library_url
    assert_response :success
    assert_select "h1", "Library"
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
  end

  test "requires sign in" do
    delete session_url(@user.sessions.last)
    get library_url
    assert_redirected_to sign_in_url
  end

  test "admin sees avo link menu on media" do
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
    assert_select "a[href=?]", avo.resources_library_media_path(media), text: "Avo"
  end

  test "non-admin does not see avo link menu" do
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
end
