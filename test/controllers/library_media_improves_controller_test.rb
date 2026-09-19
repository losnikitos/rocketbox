# frozen_string_literal: true

require "test_helper"

class LibraryMediaImprovesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @media = LibraryMedia.create!(
      telegram_file_id: "f2",
      telegram_file_unique_id: "u2-improve-ctrl",
      kind: "photo",
      user: @user
    )
    @media.file.attach(
      io: StringIO.new("fake-image"),
      filename: "shot.jpg",
      content_type: "image/jpeg"
    )
  end

  test "enqueues improve job and redirects" do
    assert_enqueued_with(job: ImproveLibraryMediaJob, args: [ @media.id ]) do
      post library_improve_url(@media)
    end

    assert_redirected_to library_url
    assert_equal "Improving with AI…", flash[:notice]
  end

  test "shows alert when media not found" do
    post library_improve_url(id: 0)

    assert_redirected_to library_url
    assert_equal "Media not found.", flash[:alert]
  end
end
