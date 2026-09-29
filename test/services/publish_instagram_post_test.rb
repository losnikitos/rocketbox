# frozen_string_literal: true

require "test_helper"

class PublishInstagramPostTest < ActiveSupport::TestCase
  IMG = { url: "https://example.com/a.jpg", video: false }.freeze
  VID = { url: "https://example.com/a.mp4", video: true }.freeze

  setup do
    @user = users(:lazaro_nixon)
    @user.update!(instagram_user_id: "ig", instagram_access_token: "tok")
  end

  test "reel is one REELS container" do
    creates = publish(format: "reel", slides: [ VID ], caption: "Hi")
    assert_equal [ { media_type: "REELS", video_url: VID[:url], caption: "Hi" } ], creates
  end

  test "single image post" do
    assert_equal [ { image_url: IMG[:url], caption: "Hi" } ], publish(format: "post", slides: [ IMG ], caption: "Hi")
  end

  test "multi-slide post is a carousel" do
    creates = publish(format: "post", slides: [ IMG, VID ], caption: "Hi")
    assert_equal [
      { image_url: IMG[:url], is_carousel_item: true },
      { media_type: "VIDEO", video_url: VID[:url], is_carousel_item: true },
      { media_type: "CAROUSEL", children: "c1,c2", caption: "Hi" }
    ], creates
    assert_equal [ "c3" ], @published
  end

  test "multi-slide story publishes each slide" do
    creates = publish(format: "story", slides: [ IMG, VID ], caption: "ignored")
    assert_equal [
      { image_url: IMG[:url], media_type: "STORIES" },
      { video_url: VID[:url], media_type: "STORIES" }
    ], creates
    assert_equal %w[c1 c2], @published
  end

  test "requires instagram credentials" do
    @user.update!(instagram_access_token: nil)
    error = assert_raises(PublishInstagramPost::Error) { PublishInstagramPost.call(user: @user, format: "reel", slides: [ VID ]) }
    assert_match(/Connect Instagram/, error.message)
  end

  private

    def publish(**args)
      creates = []
      @published = []
      service = PublishInstagramPost.new(user: @user, **args)
      published = @published
      service.define_singleton_method(:request!) do |method, path, params = {}|
        case [ method, path ]
        when [ :post, "ig/media" ]
          creates << params.except(:access_token)
          { "id" => "c#{creates.size}" }
        when [ :post, "ig/media_publish" ]
          published << params[:creation_id]
          { "id" => "m-#{params[:creation_id]}" }
        else
          { "status_code" => "FINISHED" }
        end
      end
      service.call
      creates
    end
end
