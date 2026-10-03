# frozen_string_literal: true

require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @recipe = Recipe.create!(name: "Collage", body: "Compose a collage.", format: "post",
      media_type_ids: [ media_types(:interior).id, "", media_types(:customer).id ])
    @interior = photo("interior.jpg", :interior)
    @customer = photo("customer.jpg", :customer)
    @original_paint = RubyLLM.method(:paint)
  end

  teardown do
    RubyLLM.define_singleton_method(:paint, @original_paint)
  end

  test "create_post! rejects inbox photos and photos of the wrong type" do
    inbox = photo("inbox.jpg", :customer, collection: "inbox")

    assert_raises(ActiveRecord::RecordInvalid) { @recipe.create_post!(user: @user, media: [ @interior, inbox ]) }
    assert_raises(ActiveRecord::RecordInvalid) { @recipe.create_post!(user: @user, media: [ @customer, @interior ]) }
    assert_raises(ActiveRecord::RecordInvalid) { @recipe.create_post!(user: @user, media: [ @interior ]) }
  end

  test "generate! paints every slot photo in order with the recipe's options, overridden per post, and attaches one slide" do
    calls = []
    RubyLLM.define_singleton_method(:paint) do |prompt, model:, with:, provider_options:, **|
      calls << [ prompt, model, with.map { it.filename.to_s }, provider_options ]
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"))
    end
    @recipe.update!(options: { "model" => "gpt-image-2", "aspect_ratio" => "1:1", "quality" => "high" })
    post = @recipe.create_post!(user: @user, media: [ @interior, @customer ], options: { "quality" => "low" })

    post.generate!

    assert_equal [ [ "Compose a collage.", "gpt-image-2", %w[interior.jpg customer.jpg], { size: "1920x1920", quality: "low", output_format: "jpeg" } ] ], calls
    assert_equal [ "ready", "post" ], [ post.reload.status, post.format ]
    assert_equal [ "jpeg-bytes" ], post.smm_slides.map { it.media.download }
  end

  test "a recipe with a shot group needs a shot from it, and paints the shot after the recipe body" do
    prompts = []
    RubyLLM.define_singleton_method(:paint) do |prompt, **|
      prompts << prompt
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"))
    end
    @recipe.update!(shot_group: "Daily")
    shot = Shot.create!(name: "Empty Chair", body: "The empty chair.", group: "Daily")
    other = Shot.create!(name: "Red Carpet", body: "A premiere.", group: "Events")
    media = [ @interior, @customer ]

    assert_raises(ActiveRecord::RecordInvalid) { @recipe.create_post!(user: @user, media:) }
    assert_raises(ActiveRecord::RecordInvalid) { @recipe.create_post!(user: @user, media:, shot: other) }
    post = @recipe.create_post!(user: @user, media:, shot:)
    post.generate!

    assert_equal [ "Compose a collage.\n\nThe empty chair." ], prompts
    assert_equal prompts.first, post.reload.prompt
  end

  test "generate! records a failure" do
    RubyLLM.define_singleton_method(:paint) { |*, **| raise RubyLLM::Error, "content policy" }
    post = @recipe.create_post!(user: @user, media: [ @interior, @customer ])

    post.generate!

    assert_equal [ "failed", "content policy" ], [ post.reload.status, post.error_message ]
    assert_empty post.smm_slides
  end

  private

    def photo(filename, type, collection: "photobank")
      LibraryMedia.create!(kind: "photo", media_type: media_types(type), user: @user, collection:,
        file: { io: StringIO.new("img"), filename:, content_type: "image/jpeg" })
    end
end
