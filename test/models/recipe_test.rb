# frozen_string_literal: true

require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @recipe = Recipe.create!(name: "Collage", body: "Compose a collage.",
      tag_ids: [ tags(:interior).id, "", tags(:customer).id ])
    @interior = photo("interior.jpg", :interior)
    @customer = photo("customer.jpg", :customer)
    @original_paint = RubyLLM.method(:paint)
  end

  teardown do
    RubyLLM.define_singleton_method(:paint, @original_paint)
  end

  test "run! rejects inbox photos, photos of the wrong type and another account's photos" do
    inbox = photo("inbox.jpg", :customer, collection: "inbox")
    stranger = photo("stranger.jpg", :customer, user: users(:admin_user))

    assert_no_difference -> { LibraryMedia.count } do
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(user: @user, media: [ @interior, inbox ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(user: @user, media: [ @customer, @interior ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(user: @user, media: [ @interior ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(user: @user, media: [ @interior, stranger ]) }
    end
  end

  test "run! paints every slot photo in order with the recipe's options, overridden per run, into a Ready media" do
    calls = []
    RubyLLM.define_singleton_method(:paint) do |prompt, model:, with:, provider_options:, **|
      calls << [ prompt, model, with.map { it.filename.to_s }, provider_options ]
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"), usage: { "input_tokens" => 10, "cost" => 0.04 })
    end
    @recipe.update!(options: { "model" => "gpt-image-2", "aspect_ratio" => "1:1", "quality" => "high" })
    run = @recipe.run!(user: @user, media: [ @interior, @customer ], options: { "quality" => "low" })
    media = run.generated_media

    assert_equal [ "ready", @user, "running" ], [ media.collection, media.user, run.status ]
    assert_not media.file.attached?

    run.run!

    assert_equal [ [ "Compose a collage.", "gpt-image-2", %w[interior.jpg customer.jpg], { size: "1920x1920", quality: "low", output_format: "jpeg" } ] ], calls
    assert_equal [ "complete", 0.04, "Compose a collage." ], [ run.reload.status, run.cost, run.prompt ]
    assert_equal "jpeg-bytes", media.reload.file.download
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

    assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(user: @user, media:) }
    assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(user: @user, media:, shot: other) }
    run = @recipe.run!(user: @user, media:, shot:)
    run.run!

    assert_equal [ "Compose a collage.\n\nThe empty chair." ], prompts
    assert_equal prompts.first, run.reload.prompt
  end

  test "run! records a failure" do
    RubyLLM.define_singleton_method(:paint) { |*, **| raise RubyLLM::Error, "content policy" }
    run = @recipe.run!(user: @user, media: [ @interior, @customer ])

    run.run!

    assert_equal [ "failed", "content policy" ], [ run.reload.status, run.error ]
    assert_not run.generated_media.reload.file.attached?
  end

  private

    def photo(filename, type, collection: "photobank", user: @user)
      LibraryMedia.create!(kind: "photo", tag: tags(type), user:, collection:,
        file: { io: StringIO.new("img"), filename:, content_type: "image/jpeg" })
    end
end
