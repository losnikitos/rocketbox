# frozen_string_literal: true

require "test_helper"

class GenerateSmmPostVideoTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @prompt = prompts(:cinematic)
    @media = LibraryMedia.create!(
      telegram_file_id: "f-gen",
      telegram_file_unique_id: "u-gen-media",
      kind: "photo",
      user: @user
    )
    @media.file.attach(io: StringIO.new("fake-image"), filename: "shot.jpg", content_type: "image/jpeg")

    @post = @user.smm_posts.new(prompt: @prompt, status: "draft")
    @post.smm_post_media_items.build(library_media: @media, position: 0)
    @post.save!
  end

  test "generates and attaches video from xAI" do
    video_bytes = "generated-mp4-bytes"
    service = GenerateSmmPostVideo.new(smm_post: @post)
    service.define_singleton_method(:api_key) { "test-key" }
    service.define_singleton_method(:connection) do
      respond = lambda do |path|
        case path
        when "videos/generations"
          Struct.new(:success?, :body, :status).new(true, { "request_id" => "req-1" }, 200)
        when "videos/req-1"
          Struct.new(:success?, :body, :status).new(
            true,
            { "status" => "done", "video" => { "url" => "https://example.com/out.mp4" } },
            200
          )
        else
          raise "unexpected #{path}"
        end
      end

      conn = Object.new
      conn.define_singleton_method(:post) { |path, &_| respond.call(path) }
      conn.define_singleton_method(:get) { |path, &_| respond.call(path) }
      conn
    end
    service.define_singleton_method(:download_video!) { |_url| video_bytes }

    result = service.call
    assert_equal "ready", result.status
    assert result.generated_video.attached?
    assert_equal video_bytes, result.generated_video.download
    assert_equal "req-1", result.generation_request_id
  end

  test "marks post failed on permanent errors" do
    service = GenerateSmmPostVideo.new(smm_post: @post)
    service.define_singleton_method(:api_key) { "test-key" }
    service.define_singleton_method(:connection) do
      response = Struct.new(:success?, :body, :status).new(false, { "error" => { "message" => "nope" } }, 400)
      conn = Object.new
      conn.define_singleton_method(:post) { |*_args, &_| response }
      conn
    end

    error = assert_raises(GenerateSmmPostVideo::Error) { service.call }
    assert_match(/nope/, error.message)
    assert_equal "failed", @post.reload.status
    assert_match(/nope/, @post.error_message)
  end
end
