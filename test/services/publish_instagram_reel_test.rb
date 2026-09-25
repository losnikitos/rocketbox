# frozen_string_literal: true

require "test_helper"

class PublishInstagramReelTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(instagram_user_id: "ig-user-1", instagram_access_token: "ig-token")
  end

  test "creates reel container then publishes" do
    calls = []
    service = PublishInstagramReel.new(user: @user, video_url: "https://example.com/reel.mp4", caption: "Hi")
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
    assert_equal "REELS", calls[0][2][:media_type]
    assert_equal "https://example.com/reel.mp4", calls[0][2][:video_url]
    assert_equal "Hi", calls[0][2][:caption]
    assert_equal "container-1", calls[2][2][:creation_id]
  end

  test "requires instagram credentials" do
    @user.update!(instagram_access_token: nil)

    error = assert_raises(PublishInstagramReel::Error) do
      PublishInstagramReel.call(user: @user, video_url: "https://example.com/reel.mp4")
    end

    assert_match(/Integrations/, error.message)
  end
end
