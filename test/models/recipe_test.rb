# frozen_string_literal: true

require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @recipe = Recipe.create!(name: "Collage", body: "Compose a collage.",
      inputs: [ input(:interior), { "collection" => "photobank", "tag_id" => "" }, input(:customer) ])
    @interior = photo("interior.jpg", :interior)
    @customer = photo("customer.jpg", :customer)
    @original_paint = RubyLLM.method(:paint)
    @original_animate = RubyLLM.method(:animate)
  end

  teardown do
    RubyLLM.define_singleton_method(:paint, @original_paint)
    RubyLLM.define_singleton_method(:animate, @original_animate)
  end

  test "inputs drop blank tags and need a known folder and tag; a video takes one input" do
    assert_equal [ input(:interior), input(:customer) ], @recipe.inputs

    assert_not Recipe.new(name: "x", body: "x", inputs: [ { "collection" => "attic", "tag_id" => tags(:interior).id } ]).valid?
    assert_not Recipe.new(name: "x", body: "x", inputs: [ { "collection" => "inbox", "tag_id" => 0 } ]).valid?
    assert_not Recipe.new(name: "x", body: "x", inputs: []).valid?
    assert_not Recipe.new(name: "x", body: "x", output_collection: "inbox", inputs: [ input(:interior) ]).valid?
    video = Recipe.new(name: "x", body: "x", kind: "generate_video", inputs: [ input(:interior), input(:customer) ])
    assert_not video.valid?
    assert_includes video.errors.full_messages, "Inputs must be a single photo to make a video"
  end

  test "run! rejects photos from another folder, of the wrong tag or order, and another account's photos" do
    inbox = photo("inbox.jpg", :customer, collection: "inbox")
    stranger = photo("stranger.jpg", :customer, user: users(:admin_user))

    assert_no_difference -> { LibraryMedia.count } do
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @interior, inbox ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @customer, @interior ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @interior ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @interior, stranger ]) }
    end
  end

  test "run! paints every input in order with the recipe's options, overridden per run, into the output folder" do
    calls = []
    RubyLLM.define_singleton_method(:paint) do |prompt, model:, with:, provider_options:, **|
      calls << [ prompt, model, with.map { it.filename.to_s }, provider_options ]
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"), usage: { "input_tokens" => 10, "cost" => 0.04 })
    end
    @recipe.update!(options: { "model" => "gpt-image-2", "aspect_ratio" => "1:1", "quality" => "high" })
    run = @recipe.run!(media: [ @interior, @customer ], extra_prompt: "Warmer.", options: { "quality" => "low" })
    media = run.generated_media

    assert_equal [ "ready", @user, tags(:interior), "running" ], [ media.collection, media.user, media.tag, run.status ]
    assert_equal [ @interior, @customer ], run.reload.source_media
    assert_not media.file.attached?

    run.run!

    assert_equal [ [ "Compose a collage.\n\nWarmer.", "gpt-image-2", %w[interior.jpg customer.jpg], { size: "1920x1920", quality: "low", output_format: "jpeg" } ] ], calls
    assert_equal [ "complete", 0.04, "Compose a collage.\n\nWarmer." ], [ run.reload.status, run.cost, run.prompt ]
    assert_equal "jpeg-bytes", media.reload.file.download
  end

  test "a video recipe animates its one input into a video" do
    calls = []
    RubyLLM.define_singleton_method(:animate) do |prompt, with:, **|
      calls << [ prompt, with.filename.to_s ]
      Struct.new(:to_blob).new("mp4-bytes")
    end
    source = photo("room.jpg", :interior, collection: "inbox")
    run = recipes(:cinematic).run!(media: [ source ])

    assert_equal [ "photobank", "video", tags(:interior) ], [ run.generated_media.collection, run.generated_media.kind, run.generated_media.tag ]
    run.run!

    assert_equal [ [ "Slow cinematic push-in on the shop.", "room.jpg" ] ], calls
    assert_equal "complete", run.reload.status
    assert_equal "mp4-bytes", run.generated_media.file.download
  end

  test "a stitch recipe joins its inputs into a video, 1 second each, without a prompt or shot" do
    recipe = Recipe.create!(name: "Reel", kind: "stitch", shot_group: "Daily", inputs: [ input(:interior), input(:customer) ])
    assert_nil recipe.shot_group
    media = [ @interior, @customer ].each { it.file.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png") }
    run = recipe.run!(media:)

    run.run!

    assert_equal [ "complete", nil ], [ run.reload.status, run.prompt ]
    file = run.generated_media.reload.file
    assert_equal [ "video", "video/mp4" ], [ run.generated_media.kind, file.content_type ]
    duration = file.open { Open3.capture2("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", it.path).first.to_f }
    assert_in_delta 2.0, duration, 0.1
  end

  test "a recipe with a shot group needs a shot from it, and paints the shot and style after the recipe body" do
    prompts = []
    RubyLLM.define_singleton_method(:paint) do |prompt, **|
      prompts << prompt
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"))
    end
    style = Style.create!(name: "Film", body: "35mm grain.")
    @recipe = Recipe.find(@recipe.id)
    @recipe.update!(shot_group: "Daily", options: { "style" => style.id.to_s })
    shot = Shot.create!(name: "Empty Chair", body: "The empty chair.", group: "Daily")
    other = Shot.create!(name: "Red Carpet", body: "A premiere.", group: "Events")
    media = [ @interior, @customer ]

    assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media:) }
    assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media:, shot: other) }
    run = @recipe.run!(media:, shot:)
    run.run!

    assert_equal [ "Compose a collage.\n\nThe empty chair.\n\n35mm grain." ], prompts
    assert_equal prompts.first, run.reload.prompt
  end

  test "run! records a failure" do
    RubyLLM.define_singleton_method(:paint) { |*, **| raise RubyLLM::Error, "content policy" }
    run = @recipe.run!(media: [ @interior, @customer ])

    run.run!

    assert_equal [ "failed", "content policy" ], [ run.reload.status, run.error ]
    assert_not run.generated_media.reload.file.attached?
  end

  test "gemini options become Nano Banana imageConfig and Veo parameters" do
    RubyLLM::ActiveRecord::Model.create!(provider: "gemini", model_id: "gemini-3-pro-image", name: "Nano Banana Pro", enabled: true,
      modalities: { "input" => %w[text image], "output" => %w[text image] })
    RubyLLM::ActiveRecord::Model.create!(provider: "gemini", model_id: "veo-3.1-generate-preview", name: "Veo 3.1", enabled: true,
      modalities: { "input" => %w[text image], "output" => %w[video] })

    image = @recipe.runs.new(options: { "model" => "gemini-3-pro-image", "aspect_ratio" => "4:5", "resolution" => "4k" })
    assert_equal({ model: "gemini-3-pro-image", generationConfig: { imageConfig: { aspectRatio: "4:5", imageSize: "4K" } }, provider: :gemini },
      image.ai_options)

    video = recipes(:cinematic).runs.new(options: { "model" => "veo-3.1-generate-preview", "resolution" => "1080p" })
    assert_equal({ model: "veo-3.1-generate-preview", parameters: { aspectRatio: "9:16", resolution: "1080p", durationSeconds: 8 }, provider: :gemini },
      video.ai_options)
  end

  private

    def input(tag, collection: "photobank") = { "collection" => collection, "tag_id" => tags(tag).id }

    def photo(filename, tag, collection: "photobank", user: @user)
      LibraryMedia.create!(kind: "photo", tag: tags(tag), user:, collection:,
        file: { io: StringIO.new("img"), filename:, content_type: "image/jpeg" })
    end
end
