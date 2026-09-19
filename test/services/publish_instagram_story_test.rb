# frozen_string_literal: true

require "test_helper"

class PublishInstagramStoryTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(instagram_user_id: "ig-user-1", instagram_access_token: "ig-token")
    @upload = TelegramUpload.create!(
      telegram_file_id: "f1",
      telegram_file_unique_id: "u1-story-test",
      kind: "photo",
      user: @user
    )
    @upload.file.attach(
      io: StringIO.new("fake-image"),
      filename: "shot.jpg",
      content_type: "image/jpeg"
    )
  end

  test "creates container then publishes" do
    calls = []
    service = PublishInstagramStory.new(user: @user, upload: @upload, media_url: "https://example.com/shot.jpg")
    service.define_singleton_method(:request!) do |method, path, params = {}|
      calls << [ method, path, params ]
      case [ method, path ]
      when [ :post, "ig-user-1/media" ]
        { "id" => "container-1" }
      when [ :get, "container-1" ]
        { "status_code" => "FINISHED" }
      when [ :post, "ig-user-1/media_publish" ]
        { "id" => "media-1" }
      else
        raise "unexpected #{method} #{path}"
      end
    end

    service.call

    assert_equal [ :post, "ig-user-1/media" ], calls[0].first(2)
    assert_equal "STORIES", calls[0][2][:media_type]
    assert_equal "https://example.com/shot.jpg", calls[0][2][:image_url]
    assert_equal "container-1", calls[2][2][:creation_id]
  end

  test "requires instagram credentials" do
    @user.update!(instagram_access_token: nil)

    error = assert_raises(PublishInstagramStory::Error) do
      PublishInstagramStory.call(user: @user, upload: @upload, media_url: "https://example.com/shot.jpg")
    end

    assert_match(/Integrations/, error.message)
  end
end
