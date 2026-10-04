# frozen_string_literal: true

require "test_helper"

class FeatureTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @feature = Feature.find("fully-booked")
    @original_screenshot = Layer.method(:screenshot)
    @source = LibraryMedia.create!(kind: "photo", media_type: media_types(:working), user: @user, collection: "photobank",
      file: { io: file_fixture("logo.png").open, filename: "working.png", content_type: "image/png" })
  end

  teardown do
    Layer.define_singleton_method(:screenshot, @original_screenshot)
  end

  test "create_post! needs a Ready photo from the setting's recipe" do
    error = assert_raises(ActiveRecord::RecordNotFound) { @feature.create_post!(@user) }
    assert_equal "No matching photo in Ready.", error.message

    @feature.setting_for(@user).update!(recipe: recipe("Poster"))
    ready_photo(recipe("Collage"))
    error = assert_raises(ActiveRecord::RecordNotFound) { @feature.create_post!(@user) }
    assert_equal "No Poster photo in Ready.", error.message
  end

  test "generate! renders the layer for tomorrow over a Ready photo into one story slide" do
    poster = recipe("Poster")
    @feature.setting_for(@user).update!(recipe: poster)
    ready_photo(recipe("Collage"))
    photo = ready_photo(poster)
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

  private

    def recipe(name) = Recipe.create!(name:, body: "Compose.", media_type_ids: [ media_types(:working).id ])

    def ready_photo(recipe)
      recipe.run!(user: @user, media: [ @source ]).generated_media.tap do
        it.update!(file: { io: file_fixture("logo.png").open, filename: "ready.png", content_type: "image/png" })
      end
    end
end
