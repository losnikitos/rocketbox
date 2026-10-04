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

  test "reviews renders a 5-star review on the Review layer whatever the setting's layer" do
    feature = Feature.find("reviews")
    poster = recipe("Poster")
    feature.setting_for(@user).update!(recipe: poster, layer_slug: "daily")
    ready_photo(poster)
    @user.reviews.create!(source: "google", customer_name: "Meh", rating: 4, body: "Fine.")
    @user.reviews.create!(source: "google", customer_name: "Dana K.", rating: 5, body: "Best fade in town.",
      avatar: { io: file_fixture("logo.png").open, filename: "dana.png", content_type: "image/png" })
    rendered = []
    Layer.define_singleton_method(:screenshot) { |html, size:| rendered << html and "png-bytes" }

    post = feature.create_post!(@user)
    post.generate!

    html = rendered.sole
    assert_equal "ready", post.reload.status
    assert_includes html, "Best fade in town."
    assert_includes html, "Dana K."
    assert_includes html, %(src="data:image/jpeg;base64,)
  end

  test "reviews needs an unused 5-star review" do
    feature = Feature.find("reviews")
    poster = recipe("Poster")
    feature.setting_for(@user).update!(recipe: poster)
    ready_photo(poster)
    ready_photo(poster)
    review = @user.reviews.create!(source: "google", customer_name: "Dana K.", rating: 5, body: "Best fade in town.")

    assert_equal review, feature.create_post!(@user).review
    assert_empty feature.review_backlog(@user)
    assert_equal 1, feature.photo_backlog(@user).count
    error = assert_raises(ActiveRecord::RecordNotFound) { feature.create_post!(@user) }
    assert_equal "No 5-star review with text to post.", error.message
  end

  test "daily uses recipe 8 and the Daily layer whatever the setting" do
    feature = Feature.find("daily")
    feature.setting_for(@user).update!(recipe: recipe("Poster"), layer_slug: "review")
    ready_photo(recipe("Poster"))
    photo = ready_photo(Recipe.create!(id: 8, name: "Будни", body: "Compose.", media_type_ids: [ media_types(:working).id ]))
    rendered = []
    Layer.define_singleton_method(:screenshot) { |html, size:| rendered << html and "png-bytes" }

    post = feature.create_post!(@user)
    post.generate!

    assert_equal [ "ready", [ photo ] ], [ post.reload.status, post.library_media.to_a ]
    assert_includes rendered.sole, "first clients"
  end

  private

    def recipe(name) = Recipe.create!(name:, body: "Compose.", media_type_ids: [ media_types(:working).id ])

    def ready_photo(recipe)
      recipe.run!(user: @user, media: [ @source ]).generated_media.tap do
        it.update!(file: { io: file_fixture("logo.png").open, filename: "ready.png", content_type: "image/png" })
      end
    end
end
