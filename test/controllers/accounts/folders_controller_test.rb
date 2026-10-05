# frozen_string_literal: true

require "test_helper"

class Accounts::FoldersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "root shows the three folders" do
    get library_folders_url
    assert_response :success
    assert_select "h1", "Folders"
    %w[inbox photobank ready].each { assert_select "a[href=?]", library_folders_path(it) }
  end

  test "folder shows only its own media" do
    photo = LibraryMedia.create!(kind: "photo", collection: "photobank", user: @user)
    photo.file.attach(io: StringIO.new("img"), filename: "cut.jpg", content_type: "image/jpeg")
    inbox = LibraryMedia.create!(kind: "photo", user: @user)
    inbox.file.attach(io: StringIO.new("img"), filename: "raw.jpg", content_type: "image/jpeg")

    get library_folders_url("photobank")
    assert_response :success
    assert_select "#folder-media-#{photo.id}"
    assert_select "#folder-media-#{inbox.id}", count: 0
  end

  test "unknown folder is not found" do
    get "/app/library/folders/nope"
    assert_response :not_found
  end
end
