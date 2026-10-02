# frozen_string_literal: true

require "test_helper"

class GenerationTest < ActiveSupport::TestCase
  setup do
    user = users(:lazaro_nixon)
    source = LibraryMedia.create!(kind: "photo", media_type: media_types(:interior), user:,
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    prompt = Prompt.create!(name: "Polish", media_type: media_types(:interior), body: "Polish the shot.")
    @generation = source.generations.new(prompt:, extra_prompt: "Warmer.")
    @generation.start!
    @original_paint = RubyLLM.method(:paint)
  end

  teardown do
    RubyLLM.define_singleton_method(:paint, @original_paint)
  end

  test "run! paints the source with the prompt and extra prompt and attaches the result" do
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

  test "gemini options become Nano Banana imageConfig and Veo parameters" do
    RubyLLM::ActiveRecord::Model.create!(provider: "gemini", model_id: "gemini-3-pro-image", name: "Nano Banana Pro", enabled: true,
      modalities: { "input" => %w[text image], "output" => %w[text image] })
    RubyLLM::ActiveRecord::Model.create!(provider: "gemini", model_id: "veo-3.1-generate-preview", name: "Veo 3.1", enabled: true,
      modalities: { "input" => %w[text image], "output" => %w[video] })
    source = @generation.source_media

    image = source.generations.new(prompt: @generation.prompt, options: { "model" => "gemini-3-pro-image", "aspect_ratio" => "4:5", "resolution" => "4k" })
    assert_equal({ model: "gemini-3-pro-image", generationConfig: { imageConfig: { aspectRatio: "4:5", imageSize: "4K" } }, provider: :gemini },
      image.ai_options)

    video = source.generations.new(prompt: prompts(:cinematic), options: { "model" => "veo-3.1-generate-preview", "resolution" => "1080p" })
    assert_equal({ model: "veo-3.1-generate-preview", parameters: { aspectRatio: "9:16", resolution: "1080p", durationSeconds: 8 }, provider: :gemini },
      video.ai_options)
  end
end
