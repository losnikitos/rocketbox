# frozen_string_literal: true

require "test_helper"

class PublishInstagramStoryJobTest < ActiveJob::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(instagram_user_id: "ig-user-1", instagram_access_token: "ig-token")
    @media = LibraryMedia.create!(
      telegram_file_id: "f2",
      telegram_file_unique_id: "u2-story-job",
      kind: "photo",
      user: @user
    )
    @media.file.attach(
      io: StringIO.new("fake-image"),
      filename: "shot.jpg",
      content_type: "image/jpeg"
    )
  end

  test "calls PublishInstagramStory with media" do
    called_with = nil
    original = PublishInstagramStory.method(:call)
    PublishInstagramStory.define_singleton_method(:call) do |**kwargs|
      called_with = kwargs
      true
    end

    PublishInstagramStoryJob.perform_now(@media.id)

    assert_equal @user, called_with[:user]
    assert_equal @media, called_with[:media]
    assert called_with[:media_url].present?
  ensure
    PublishInstagramStory.define_singleton_method(:call, original)
  end
end
