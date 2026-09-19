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

  test "publishes story and redirects" do
    with_publish_stub(->(**_) { true }) do
      post library_instagram_story_url(@media)
    end

    assert_redirected_to library_url
    assert_equal "Published to Instagram Stories.", flash[:notice]
  end

  test "shows api error as alert" do
    with_publish_stub(->(**_) { raise PublishInstagramStory::Error, "bad token" }) do
      post library_instagram_story_url(@media)
    end

    assert_redirected_to library_url
    assert_equal "bad token", flash[:alert]
  end

  private

    def with_publish_stub(callable)
      original = PublishInstagramStory.method(:call)
      PublishInstagramStory.define_singleton_method(:call) { |**kwargs| callable.call(**kwargs) }
      yield
    ensure
      PublishInstagramStory.define_singleton_method(:call, original)
    end
end
