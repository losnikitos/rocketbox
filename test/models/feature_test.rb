# frozen_string_literal: true

require "test_helper"

class FeatureTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @feature = Feature.find("fully-booked")
    @original_screenshot = Layer.method(:screenshot)
  end

  teardown do
    Layer.define_singleton_method(:screenshot, @original_screenshot)
  end

  test "create_post! needs a photobank photo of the setting's type" do
    error = assert_raises(ActiveRecord::RecordNotFound) { @feature.create_post!(@user) }
    assert_equal "No Working photo in the photobank.", error.message
  end

  test "generate! renders the layer for tomorrow over a working photo into one story slide" do
    LibraryMedia.create!(kind: "photo", media_type: media_types(:customer), user: @user, collection: "photobank",
      file: { io: file_fixture("logo.png").open, filename: "customer.png", content_type: "image/png" })
    photo = LibraryMedia.create!(kind: "photo", media_type: media_types(:working), user: @user, collection: "photobank",
      file: { io: file_fixture("logo.png").open, filename: "working.png", content_type: "image/png" })
    rendered = []
    Layer.define_singleton_method(:screenshot) do |html, size:|
      rendered << [ html, size ]
      "png-bytes"
    end

    post = @feature.create_post!(@user)
    post.generate!

    html, size = rendered.sole
    assert_equal [ 1080, 1920 ], size
    assert_includes html, "background-image: url(data:image/jpeg;base64,"
    assert_includes html, Date.tomorrow.strftime("%a, %b %-d")
    assert_equal [ "ready", "story", "fully-booked", [ photo ] ], [ post.reload.status, post.format, post.feature_slug, post.library_media.to_a ]
    assert_equal [ "png-bytes" ], post.smm_slides.map { it.media.download }
  end
end
