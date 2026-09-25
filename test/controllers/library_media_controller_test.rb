# frozen_string_literal: true

require "test_helper"

class LibraryMediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    @media = LibraryMedia.create!(
      telegram_file_id: "f-remove",
      telegram_file_unique_id: "u-remove-ctrl",
      kind: "photo",
      user: @admin
    )
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "admin can remove media" do
    assert_difference -> { LibraryMedia.count }, -1 do
      delete library_media_url(@media)
    end

    assert_redirected_to library_uploads_url
    assert_equal "Media removed.", flash[:notice]
  end

  test "non-admin cannot remove media" do
    sign_in_as(users(:lazaro_nixon))
    media = LibraryMedia.create!(
      telegram_file_id: "f-user-remove",
      telegram_file_unique_id: "u-user-remove",
      kind: "photo",
      user: users(:lazaro_nixon)
    )

    assert_no_difference -> { LibraryMedia.count } do
      delete library_media_url(media)
    end

    assert_redirected_to library_uploads_url
    assert_equal "You are not allowed to remove media.", flash[:alert]
  end

  test "shows alert when media not found" do
    delete library_media_url(id: 0)

    assert_redirected_to library_uploads_url
    assert_equal "Media not found.", flash[:alert]
  end
end

