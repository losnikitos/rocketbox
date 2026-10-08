# frozen_string_literal: true

require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @recipe = create_recipe(name: "Collage", body: "Compose a collage.",
      inputs: [ input(:photobank_interior), { "folder_id" => "" }, input(:photobank_customer) ])
    @interior = photo("interior.jpg", :photobank_interior)
    @customer = photo("customer.jpg", :photobank_customer)
    @original_paint = RubyLLM.method(:paint)
    @original_animate = RubyLLM.method(:animate)
    @original_screenshot = Layer.method(:screenshot)
  end

  teardown do
    RubyLLM.define_singleton_method(:paint, @original_paint)
    RubyLLM.define_singleton_method(:animate, @original_animate)
    Layer.define_singleton_method(:screenshot, @original_screenshot)
  end

  test "inputs drop blank folders and need a known folder; output goes to photobank; a video takes one input" do
    assert_equal [ input(:photobank_interior), input(:photobank_customer) ], @recipe.inputs
    assert new_recipe(name: "x", body: "x", inputs: [ input(:interior) ]).valid?

    assert_not new_recipe(name: "x", body: "x", inputs: [ { "folder_id" => 0 } ]).valid?
    assert_not new_recipe(name: "x", body: "x", inputs: []).valid?
    assert_not new_recipe(name: "x", kind: "steps", inputs: []).valid?
    assert_not new_recipe(name: "x", body: "x", output_folder: folders(:inbox), inputs: [ input(:interior) ]).valid?
    assert_not new_recipe(name: "x", body: "x", output_folder: folders(:interior), inputs: [ input(:interior) ]).valid?
    assert new_recipe(name: "x", body: "x", output_folder: folders(:photobank_logo), inputs: [ input(:interior) ]).valid?
    video = new_recipe(name: "x", body: "x", kind: "generate_video", inputs: [ input(:interior), input(:customer) ])
    assert_not video.valid?
    assert_includes video.errors.full_messages, "Inputs must be a single photo to make a video"
    assert_not new_recipe(name: "x", body: "x", kind: "generate_video", inputs: [ input(:interior, 2) ]).valid?
  end

  test "inputs from one folder merge, their counts summed; a missing count is 1" do
    recipe = new_recipe(inputs: [ { "folder_id" => folders(:interior).id.to_s }, input(:customer, 5), input(:interior, 2) ])
    assert_equal [ input(:interior, 3), input(:customer, 5) ], recipe.inputs
    assert_equal 8, recipe.media_count
  end

  test "slug follows the name, is never numeric, and old slugs still find the recipe" do
    assert_equal "collage", @recipe.slug
    @recipe.update!(name: "Renamed")
    assert_equal [ "renamed", @recipe, @recipe ], [ @recipe.slug, Recipe.find("renamed"), Recipe.find("collage") ]
    numeric = create_recipe(name: "2", body: "x", inputs: [ input(:interior) ])
    assert_equal [ "recipe-2", numeric ], [ numeric.slug, Recipe.find("recipe-2") ]
    assert_equal "strizhka-i-boroda", create_recipe(name: "Стрижка и борода", body: "x", inputs: [ input(:interior) ]).slug
  end

  test "run! takes each input's count from its folder, in any order, and rejects other folders, duplicates and another account's photos" do
    inbox = photo("inbox.jpg", :customer)
    stranger = photo("stranger.jpg", :photobank_customer, user: users(:admin_user))
    @recipe.update!(inputs: [ input(:photobank_interior, 2), input(:photobank_customer) ])
    interior = photo("interior2.jpg", :photobank_interior)

    assert_no_difference -> { LibraryMedia.count } do
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @interior, interior, inbox ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @interior, @customer ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @interior, @interior, @customer ]) }
      assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ @interior, interior, stranger ]) }
    end
    assert_equal [ @customer, @interior, interior ], @recipe.run!(media: [ @customer, @interior, interior ]).source_media
  end

  test "a tagged input takes only media with its tag, in any order; output tags land on what it makes" do
    before, after = tags(:before), tags(:after)
    assert_equal "new-tag", Tag.create!(name: " #New-Tag ").name
    plain, other = photo("plain.jpg", :photobank_interior), photo("other.jpg", :photobank_interior)
    @interior.tags << before
    @recipe.update!(inputs: [ input(:photobank_interior), input(:photobank_interior).merge("tag_id" => before.id.to_s) ], output_tag_ids: [ after.id.to_s, "" ])
    assert_equal [ input(:photobank_interior), input(:photobank_interior).merge("tag_id" => before.id) ], @recipe.inputs
    assert_equal [ after.id ], @recipe.output_tag_ids

    assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media: [ plain, other ]) }
    run = @recipe.run!(media: [ @interior, plain ])
    assert_equal [ after ], run.generated_media.tags.to_a

    tagged_only = create_recipe(name: "Tagged", body: "x", inputs: [ input(:photobank_interior).merge("tag_id" => before.id) ])
    assert_includes @interior.recipes, tagged_only
    assert_not_includes plain.recipes, tagged_only

    assert_not new_recipe(name: "x", body: "x", inputs: [ input(:interior).merge("tag_id" => 0) ]).valid?
    assert_not new_recipe(name: "x", body: "x", inputs: [ input(:interior) ], output_tag_ids: [ 0 ]).valid?
  end

  test "run! paints every input in order with the recipe as given, unsaved edits included, into the output folder" do
    calls = []
    RubyLLM.define_singleton_method(:paint) do |prompt, model:, with:, provider_options:, **|
      calls << [ prompt, model, with.map { it.filename.to_s }, provider_options ]
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"), usage: { "input_tokens" => 10, "cost" => 0.04 })
    end
    transformation = @recipe.transformation
    transformation.update!(options: { "model" => "gpt-image-2", "aspect_ratio" => "1:1", "quality" => "high" })
    transformation.assign_attributes(body: "Compose a collage.\n\nWarmer.", options: transformation.options.merge("quality" => "low"))
    run = @recipe.run!(media: [ @interior, @customer ])
    assert_equal "Compose a collage.", transformation.reload.body
    media = run.generated_media

    assert_equal [ folders(:ready), @user, "running" ], [ media.folder, media.user, run.status ]
    assert_equal [ @interior, @customer ], run.reload.source_media
    assert_not media.file.attached?

    run.run!

    assert_equal [ [ "Compose a collage.\n\nWarmer.", "gpt-image-2", %w[interior.jpg customer.jpg], { size: "1920x1920", quality: "low", output_format: "jpeg" } ] ], calls
    assert_equal [ "complete", 0.04, "Compose a collage.\n\nWarmer." ], [ run.reload.status, run.cost, run.prompt ]
    assert_equal "jpeg-bytes", media.reload.file.download
    assert_equal "generate_image_#{run.id}.jpg", media.file.filename.to_s
  end

  test "a video recipe animates its one input into a video" do
    calls = []
    RubyLLM.define_singleton_method(:animate) do |prompt, with:, **|
      calls << [ prompt, with.filename.to_s ]
      Struct.new(:to_blob).new("mp4-bytes")
    end
    source = photo("room.jpg", :interior)
    run = recipes(:cinematic).run!(media: [ source ])

    assert_equal [ folders(:photobank_interior), "video" ], [ run.generated_media.folder, run.generated_media.kind ]
    run.run!

    assert_equal [ [ "Slow cinematic push-in on the shop.", "room.jpg" ] ], calls
    assert_equal "complete", run.reload.status
    assert_equal "mp4-bytes", run.generated_media.file.download
  end

  test "a steps recipe joins its inputs into a video, 1 second each, without a prompt or shot" do
    recipe = create_recipe(name: "Reel", kind: "steps", shot_group: "Daily", inputs: [ input(:photobank_interior), input(:photobank_customer) ])
    assert_nil recipe.shot_group
    media = [ @interior, @customer ].each { it.file.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png") }
    run = recipe.run!(media:)

    run.run!

    assert_equal [ "complete", nil ], [ run.reload.status, run.prompt ]
    file = run.generated_media.reload.file
    assert_equal [ "video", "video/mp4", "steps_#{run.id}.mp4" ], [ run.generated_media.kind, file.content_type, file.filename.to_s ]
    duration = file.open { Open3.capture2("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", it.path).first.to_f }
    assert_in_delta 2.0, duration, 0.1
  end

  { "doppler" => 9.6, "welcome" => 8.1, "black_eyed_peas" => 7.0, "azzurro" => 6.4, "gm_visuals" => 10.2 }.each do |kind, length|
    test "a #{kind} recipe lays its track under its cuts" do
      recipe = create_recipe(name: kind, kind:, inputs: [ input(:photobank_interior), input(:photobank_customer) ])
      media = [ @interior, @customer ].each { it.file.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png") }
      run = recipe.run!(media:)

      run.run!

      assert_equal "complete", run.reload.status, run.error
      probe = run.generated_media.reload.file.open do
        Open3.capture2("ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type", "-of", "csv=p=0", it.path).first
      end
      assert_equal %w[video audio], probe.lines.map(&:strip).grep(/\A[a-z]+\z/)
      assert_in_delta length, probe.lines.last.to_f, 0.1
    end
  end

  test "gm_visuals speed-ramps videos shorter than their cuts without coming up short" do
    recipe = create_recipe(name: "GM", kind: "gm_visuals", inputs: [ input(:photobank_interior), input(:photobank_customer) ])
    Dir.mktmpdir do |dir|
      clip = File.join(dir, "clip.mp4")
      system("ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=320x240:rate=30:duration=1", "-pix_fmt", "yuv420p", clip, exception: true)
      [ @interior, @customer ].each { it.update!(kind: "video", file: { io: StringIO.new(File.binread(clip)), filename: "clip.mp4", content_type: "video/mp4" }) }
    end
    run = recipe.run!(media: [ @interior, @customer ])

    run.run!

    assert_equal "complete", run.reload.status, run.error
    frames = run.generated_media.reload.file.open do
      Open3.capture2("ffprobe", "-v", "error", "-count_frames", "-select_streams", "v", "-show_entries", "stream=nb_read_frames", "-of", "csv=p=0", it.path).first.to_i
    end
    assert_equal (10.194 * 30).round, frames
  end

  test "a reel overlays its first cuts with its type's layer, each filled from its own step" do
    recipe = create_recipe(name: "Black eyed peas", kind: "black_eyed_peas",
      inputs: [ input(:photobank_interior), input(:photobank_customer) ],
      layer_steps: [ { "line2" => "coffee" }, { "line1" => "", "line2" => "" }, { "line1" => "Our", "line2" => "tools" }, { "line2" => "" } ])
    assert_equal [ { "line2" => "coffee" }, {}, { "line1" => "Our", "line2" => "tools" }, {} ], recipe.transformation.layer_steps
    media = [ @interior, @customer ].each { it.file.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png") }
    png, htmls = file_fixture("logo.png").binread, []
    Layer.define_singleton_method(:screenshot) { |html, size:| htmls << html and png }

    run = recipe.run!(media:)
    run.run!

    assert_equal "complete", run.reload.status, run.error
    assert_equal [ %w[The coffee], %w[Our tools] ], htmls.map { it.scan(/<p class="font-[^>]*>([^<]*)</).flatten }
    assert htmls.none? { it.include?("background-image: url(") }
  end

  test "welcome lays its one step over just the first four cuts" do
    steps = [ { "line1" => "Hi" }, { "line1" => "ignored" } ]
    assert_equal [ *[ { "line1" => "Hi" } ] * 4, nil ], (0..4).map { Reels::Welcome.new(TransformationRun.new(transformation: Transformation.new(layer_steps: steps))).layer_values(it) }
  end

  test "a one-step reel lays its step over every cut" do
    assert_equal [ { "text" => "Hi" } ] * 3, [ 0, 7, 30 ].map { Reels::Doppler.new(TransformationRun.new(transformation: Transformation.new(layer_steps: [ { "text" => "Hi" } ]))).layer_values(it) }
  end

  test "every scripted type with a track has its cut ends" do
    Transformation::Type.all.select { it.reel? && it.track }.each { assert it.dir.join("beats.csv").exist?, it.slug }
  end

  test "every type has its cover" do
    Transformation::Type.all.each { assert Rails.root.join("app/assets/images", it.cover).exist?, it.slug }
  end

  test "a recipe with a shot group needs a shot from it, and paints the shot and its fixed style after the recipe body" do
    prompts = []
    RubyLLM.define_singleton_method(:paint) do |prompt, **|
      prompts << prompt
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"))
    end
    style = Style.create!(name: "Film", body: "35mm grain.")
    @recipe = Recipe.find(@recipe.id)
    @recipe.update!(transformation_attributes: { shot_group: "Daily", style: })
    shot = Shot.create!(name: "Empty Chair", body: "The empty chair.", group: "Daily")
    other = Shot.create!(name: "Red Carpet", body: "A premiere.", group: "Events")
    media = [ @interior, @customer ]

    assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media:) }
    assert_raises(ActiveRecord::RecordInvalid) { @recipe.run!(media:, shot: other) }
    run = @recipe.run!(media:, shot:)
    run.run!

    assert_equal [ "Compose a collage.\n\nThe empty chair.\n\n35mm grain." ], prompts
    assert_equal [ prompts.first, style ], [ run.reload.prompt, run.style ]
  end

  test "a type drops the inputs it doesn't take, and is fixed once saved" do
    style = Style.create!(name: "Film", body: "35mm grain.")
    review = create_recipe(name: "Reviews", kind: "review", style:, shot_group: "Daily", inputs: [ input(:photobank_interior) ])
    assert_equal [ nil, nil, true, "review" ], [ review.style, review.shot_group, review.takes_review?, review.layer.slug ]

    image = create_recipe(name: "Collage", kind: "generate_image", body: "x", style:, shot_group: "Daily", inputs: [ input(:photobank_interior) ])
    assert_equal [ style, "Daily", false, nil ], [ image.style, image.shot_group, image.takes_review?, image.layer ]

    assert_not review.update(transformation_attributes: { kind: "generate_image" })
    assert_includes review.errors.full_messages, "Transformation kind can't be changed"
    assert_equal "review", review.transformation.reload.kind
  end

  test "a recipe needs a known type, which fixes its layer; an overlay takes one input" do
    assert_equal [ "fully-booked-color", "Overlay · Fully booked" ], Transformation.new(kind: "fully_booked").then { [ it.layer.slug, it.type_label ] }
    assert_nil Transformation.new(kind: "steps").layer
    assert new_recipe(name: "x", kind: "daily", inputs: [ input(:ready) ]).valid?
    assert_not new_recipe(name: "x", kind: "scripted", inputs: [ input(:ready) ]).valid?
    assert_not new_recipe(name: "x", kind: "nope", inputs: [ input(:ready) ]).valid?
    assert_not new_recipe(name: "x", kind: "daily", inputs: []).valid?
    two = new_recipe(name: "x", kind: "daily", inputs: [ input(:ready), input(:ready) ])
    assert_not two.valid?
    assert_includes two.errors.full_messages, "Inputs must be a single photo or video to make a story"
    assert new_recipe(name: "x", kind: "welcome", inputs: [ input(:ready), input(:ready) ]).valid?
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

    image = @recipe.transformation.runs.new(options: { "model" => "gemini-3-pro-image", "aspect_ratio" => "4:5", "resolution" => "4k" })
    assert_equal({ model: "gemini-3-pro-image", generationConfig: { imageConfig: { aspectRatio: "4:5", imageSize: "4K" } }, provider: :gemini },
      image.ai_options)

    video = recipes(:cinematic).transformation.runs.new(options: { "model" => "veo-3.1-generate-preview", "resolution" => "1080p" })
    assert_equal({ model: "veo-3.1-generate-preview", parameters: { aspectRatio: "9:16", resolution: "1080p", durationSeconds: 8 }, provider: :gemini },
      video.ai_options)
  end

  test "an overlay renders its layer for today over the photo into its output folder" do
    feature = create_recipe(name: "Fully booked", kind: "fully_booked", inputs: [ input(:ready) ],
      output_folder: folders(:photobank_logo))
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user,
      file: { io: file_fixture("logo.png").open, filename: "ready.png", content_type: "image/png" })
    rendered = stub_screenshot

    assert_raises(ActiveRecord::RecordInvalid) { feature.run!(media: [ @interior ]) }
    assert_raises(ActiveRecord::RecordInvalid) { feature.run!(media: [ photo ], user: users(:admin_user)) }
    run = feature.run!(media: [ photo ])
    run.run!

    html, size = rendered.sole
    assert_equal [ 1080, 1920 ], size
    assert_includes html, "background-image: url(data:image/jpeg;base64,"
    assert_includes html, Date.current.strftime("%-d %B")
    media = run.reload.generated_media
    assert_equal [ "complete", nil, "photo", folders(:photobank_logo), [ photo ] ], [ run.status, run.prompt, media.kind, media.folder, run.source_media ]
    assert_equal [ "image/png", "png-bytes" ], [ media.file.content_type, media.file.download ]
  end

  test "an overlay over a video lays its transparent layer over the video, as a video" do
    feature = create_recipe(name: "Daily", kind: "daily", inputs: [ input(:ready) ])
    clip = Tempfile.new([ "clip", ".mp4" ])
    Open3.capture2e("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=320x240:duration=1:rate=30", "-pix_fmt", "yuv420p", clip.path)
    video = LibraryMedia.create!(kind: "video", folder: folders(:ready), user: @user,
      file: { io: File.open(clip.path), filename: "clip.mp4", content_type: "video/mp4" })
    assert feature.takes?(video)
    assert_not @recipe.takes?(video)
    png, htmls = file_fixture("logo.png").binread, []
    Layer.define_singleton_method(:screenshot) { |html, size:| htmls << html and png }

    run = feature.run!(media: [ video ])
    run.run!

    assert_equal "complete", run.reload.status, run.error
    assert_not_includes htmls.sole, "background-image: url("
    media = run.generated_media.reload
    assert_equal [ "video", "video/mp4" ], [ media.kind, media.file.content_type ]
    probe = media.file.open { Open3.capture2("ffprobe", "-v", "error", "-show_entries", "stream=width,height:format=duration", "-of", "csv=p=0", it.path).first }
    assert_equal "1080,1920", probe.lines.first.strip
    assert_in_delta 1.0, probe.lines.last.to_f, 0.1
  end

  test "crop takes one photo or video and makes the same, its middle 9:16 at 1080x1920" do
    assert_equal "Edit · Crop", Transformation.new(kind: "crop").type_label
    assert_not new_recipe(name: "x", kind: "crop", inputs: [ input(:ready), input(:ready) ]).valid?
    crop = Transformation.create!(name: "Crop", kind: "crop")
    clip = Tempfile.new([ "clip", ".mp4" ])
    system("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=320x240:duration=1:rate=30", "-f", "lavfi", "-i", "sine=duration=1",
      "-pix_fmt", "yuv420p", "-shortest", clip.path, exception: true)
    video = LibraryMedia.create!(kind: "video", folder: folders(:ready), user: @user, file: { io: File.open(clip.path), filename: "clip.mp4", content_type: "video/mp4" })
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user, file: { io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png" })

    [ [ video, "video", "video/mp4", 2 ], [ photo, "photo", "image/jpeg", 1 ] ].each do |source, kind, content_type, streams|
      run = crop.run!(media: [ source ], folder: folders(:photobank_logo))
      run.run!

      assert_equal "complete", run.reload.status, run.error
      media = run.generated_media.reload
      assert_equal [ kind, content_type ], [ media.kind, media.file.content_type ]
      probe = media.file.open { Open3.capture2("ffprobe", "-v", "error", "-show_entries", "stream=width,height", "-of", "csv=p=0", it.path).first }
      assert_equal [ "1080,1920", streams ], [ probe.lines.first.strip, probe.lines.size ]
    end
  end

  test "a review recipe needs a review and renders it on its layer" do
    feature = create_recipe(name: "Reviews", kind: "review", inputs: [ input(:ready) ])
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user,
      file: { io: file_fixture("logo.png").open, filename: "ready.png", content_type: "image/png" })
    review = @user.reviews.create!(source: "google", customer_name: "Dana K.", rating: 5, body: "Best fade in town.",
      avatar: { io: file_fixture("logo.png").open, filename: "dana.png", content_type: "image/png" })
    @user.reviews.create!(source: "google", customer_name: "Meh", rating: 4, body: "Fine.")
    rendered = stub_screenshot

    assert_equal [ review ], @user.reviews.postable.to_a
    assert_raises(ActiveRecord::RecordInvalid) { feature.run!(media: [ photo ]) }
    assert_raises(ActiveRecord::RecordInvalid) { feature.run!(media: [ photo ], review: users(:admin_user).reviews.create!(source: "google", customer_name: "X", rating: 5, body: "Hi.")) }
    run = feature.run!(media: [ photo ], review:)
    run.run!

    html, = rendered.sole
    assert_equal [ "complete", review ], [ run.reload.status, run.review ]
    assert_includes html, "Best fade in town."
    assert_includes html, "Dana K."
    assert_includes html, %(src="data:image/jpeg;base64,)
  end

  private

    def input(folder, count = 1) = { "folder_id" => folders(folder).id, "count" => count }
    def stub_screenshot
      rendered = []
      Layer.define_singleton_method(:screenshot) { |html, size:| rendered << [ html, size ] and "png-bytes" }
      rendered
    end

    def photo(filename, folder, user: @user)
      LibraryMedia.create!(kind: "photo", folder: folders(folder), user:,
        file: { io: StringIO.new("img"), filename:, content_type: "image/jpeg" })
    end
end
