# frozen_string_literal: true

require "test_helper"

class Transformation::PublishTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:lazaro_nixon)
    @user.update!(whatsapp_phone: "15551234567")
    @video = @user.library_media.create!(kind: "video", folder: folders(:ready),
      file: { io: StringIO.new("mp4"), filename: "reel.mp4", content_type: "video/mp4" })
    @publish = Transformation.create!(name: "Publish", kind: "publish", body: "Publishing to Instagram...",
      options: { "done" => "Your reel has been published", "button" => "View on Instagram" })
  end

  test "type forwards one video and has a cover" do
    type = Transformation::Publish
    assert_includes Transformation::Type.all, type
    assert type.forwards?
    assert_equal({ video: 1..1 }, type.inputs)
    assert Rails.root.join("app/assets/images", type.cover).exist?
  end

  test "publishes the same video, stores the permalink, and sends both lines" do
    texts = []
    links = []
    original_text = WhatsappCloud.method(:send_text)
    original_cta = WhatsappCloud.method(:send_cta_url)
    original_call = PublishInstagramPost.method(:call)
    original_permalink = PublishInstagramPost.method(:permalink)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| texts << args[:body] }
    WhatsappCloud.define_singleton_method(:send_cta_url) { |**args| links << args }
    PublishInstagramPost.define_singleton_method(:call) { |**| [ "ig-1" ] }
    PublishInstagramPost.define_singleton_method(:permalink) { |**| "https://www.instagram.com/reel/abc" }

    assert_no_difference -> { LibraryMedia.count } do
      @run = @publish.run!(items: [ @video ], folder: folders(:ready))
      perform_enqueued_jobs(only: GenerateJob)
    end

    assert_equal [ @video, "complete", "https://www.instagram.com/reel/abc" ],
      [ @run.reload.result, @run.status, @run.options["permalink"] ]
    assert_equal [ "Publishing to Instagram..." ], texts
    assert_equal "Your reel has been published", links.sole[:body]
    assert_equal "View on Instagram", links.sole[:display_text]
    assert_equal "https://www.instagram.com/reel/abc", links.sole[:url]
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original_text) if original_text
    WhatsappCloud.define_singleton_method(:send_cta_url, original_cta) if original_cta
    PublishInstagramPost.define_singleton_method(:call, original_call) if original_call
    PublishInstagramPost.define_singleton_method(:permalink, original_permalink) if original_permalink
  end
end
