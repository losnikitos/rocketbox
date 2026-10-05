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
    assert_select "#tag-menu-#{photo.id} form[action=?]", library_media_path(photo)
  end

  test "folder filters by tag" do
    logo = LibraryMedia.create!(kind: "photo", collection: "photobank", user: @user, tag: tags(:logo))
    logo.file.attach(io: StringIO.new("img"), filename: "logo.jpg", content_type: "image/jpeg")
    other = LibraryMedia.create!(kind: "photo", collection: "photobank", user: @user, tag: tags(:interior))
    other.file.attach(io: StringIO.new("img"), filename: "room.jpg", content_type: "image/jpeg")

    get library_folders_url("photobank", tag: "logo")
    assert_response :success
    assert_select "main a[aria-selected=true][href=?]", library_folders_path("photobank", tag: "logo")
    assert_select "#folder-media-#{logo.id}"
    assert_select "#folder-media-#{other.id}", count: 0
  end

  test "recipes panel lists recipes reading from the folder and tag" do
    cinematic, before_after = new_recipe_run_path(recipes(:cinematic)), new_recipe_run_path(recipes(:before_after))

    get library_folders_url("inbox")
    assert_select "aside[aria-labelledby=folder-recipes-heading] a[href=?]", cinematic
    assert_select "aside[aria-labelledby=folder-recipes-heading] a[href=?]", before_after

    get library_folders_url("inbox", tag: "interior")
    assert_select "aside[aria-labelledby=folder-recipes-heading] a[href=?]", cinematic
    assert_select "aside[aria-labelledby=folder-recipes-heading] a[href=?]", before_after, count: 0

    get library_folders_url("photobank")
    assert_select "aside[aria-labelledby=folder-recipes-heading] a", count: 0
    assert_select "aside[aria-labelledby=folder-recipes-heading]", /No recipes use this folder/
  end

  test "unknown folder is not found" do
    get "/app/library/folders/nope"
    assert_response :not_found
  end
end
