# frozen_string_literal: true

require "test_helper"

class GenerationTest < ActiveSupport::TestCase
  setup do
    user = users(:lazaro_nixon)
    source = LibraryMedia.create!(kind: "photo", media_type: media_types(:interior), user:,
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    recipe = Recipe.create!(name: "Polish", media_type: media_types(:interior), prompt: "Polish the shot.")
    @generation = source.generations.new(recipe:, prompt: "Warmer.")
    @generation.start!
    @original_paint = RubyLLM.method(:paint)
  end

  teardown do
    RubyLLM.define_singleton_method(:paint, @original_paint)
  end

  test "run! paints the source with the recipe and extra prompt and attaches the result" do
    calls = []
    RubyLLM.define_singleton_method(:paint) { |prompt, with:, **| calls << [ prompt, with.filename.to_s ]; RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes")) }

    @generation.run!

    assert_equal [ [ "Polish the shot.\n\nWarmer.", "a.jpg" ] ], calls
    assert_equal "complete", @generation.reload.status
    assert_equal "jpeg-bytes", @generation.generated_media.file.download
    assert_equal "photo", @generation.generated_media.kind
  end

  test "run! records a failure" do
    RubyLLM.define_singleton_method(:paint) { |*, **| raise RubyLLM::Error, "content policy" }

    @generation.run!

    assert_equal [ "failed", "content policy" ], [ @generation.reload.status, @generation.error ]
    assert_not @generation.generated_media.file.attached?
  end
end
