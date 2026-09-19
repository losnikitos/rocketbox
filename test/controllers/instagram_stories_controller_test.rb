# frozen_string_literal: true

require "test_helper"

class InstagramStoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @user.update!(instagram_user_id: "ig-user-1", instagram_access_token: "ig-token")
    @media = LibraryMedia.create!(
      telegram_file_id: "f2",
      telegram_file_unique_id: "u2-story-ctrl",
      kind: "photo",
      user: @user
    )
    @media.file.attach(
      io: StringIO.new("fake-image"),
      filename: "shot.jpg",
      content_type: "image/jpeg"
    )
  end

  test "enqueues publish job and redirects" do
    assert_enqueued_with(job: PublishInstagramStoryJob, args: [ @media.id ]) do
      post library_instagram_story_url(@media)
    end

    assert_redirected_to account_url
    assert_equal "Publishing to Instagram Stories…", flash[:notice]
  end

  test "shows alert when media not found" do
    post library_instagram_story_url(id: 0)

    assert_redirected_to account_url
    assert_equal "Media not found.", flash[:alert]
  end
end
