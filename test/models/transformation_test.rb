# frozen_string_literal: true

require "test_helper"

class TransformationTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @collage = Transformation.create!(name: "Collage", kind: "generate_image", body: "Compose a collage.")
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

  test "run! rejects duplicates and another account's photos" do
    stranger = photo("stranger.jpg", :photobank_customer, user: users(:admin_user))

    assert_no_difference -> { LibraryMedia.count } do
      assert_raises(ActiveRecord::RecordInvalid) { start(@collage, [ @interior, @interior ]) }
      assert_raises(ActiveRecord::RecordInvalid) { start(@collage, [ @interior, stranger ]) }
    end
    assert_equal [ @customer, @interior ], start(@collage, [ @customer, @interior ]).source_media
  end

  test "run! paints every input in order with the transformation as given, unsaved edits included, into the given folder" do
    calls = []
    RubyLLM.define_singleton_method(:paint) do |prompt, model:, with:, provider_options:, **|
      calls << [ prompt, model, with.map { it.filename.to_s }, provider_options ]
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"), usage: { "input_tokens" => 10, "cost" => 0.04 })
    end
    @collage.update!(options: { "model" => "gpt-image-2", "aspect_ratio" => "1:1", "quality" => "high" })
    @collage.assign_attributes(body: "Compose a collage.\n\nWarmer.", options: @collage.options.merge("quality" => "low"))
    run = start(@collage, [ @interior, @customer ])
    assert_equal "Compose a collage.", @collage.reload.body
    media = run.generated_media

    assert_equal [ folders(:ready), @user, "running" ], [ media.folder, media.user, run.status ]
    assert_equal [ @interior, @customer ], run.reload.source_media
    assert_not media.file.attached?

    run.run!

    assert_equal [ [ "Compose a collage.\n\nWarmer.", "gpt-image-2", %w[interior.jpg customer.jpg], { size: "1920x1920", quality: "low", output_format: "jpeg" } ] ], calls
    assert_equal [ "complete", 0.04, "Compose a collage.\n\nWarmer." ], [ run.reload.status, run.cost, run.prompt_text ]
    assert_equal "jpeg-bytes", media.reload.file.download
    assert_equal "generate_image_#{run.id}.jpg", media.file.filename.to_s
  end

  test "a video animates its inputs into a video" do
    assert_equal "grok-imagine-video-1.5 · 9:16 · 720p · 8 s", Transformation.new(kind: "generate_video").options_label
    calls = []
    RubyLLM.define_singleton_method(:animate) do |prompt, with:, **|
      calls << [ prompt, *with.map { it.filename.to_s } ]
      Struct.new(:to_blob).new("mp4-bytes")
    end
    source = photo("room.jpg", :interior)
    run = transformations(:cinematic).run!(media: [ source ], folder: folders(:photobank_interior))

    assert_equal [ folders(:photobank_interior), "video" ], [ run.generated_media.folder, run.generated_media.kind ]
    run.run!

    assert_equal [ [ "Slow cinematic push-in on the shop.", "room.jpg" ] ], calls
    assert_equal "complete", run.reload.status
    assert_equal "mp4-bytes", run.generated_media.file.download
  end

  test "steps joins its inputs into a video, 1 second each, without a prompt" do
    steps = Transformation.create!(name: "Reel", kind: "steps", prompt_folder: "Shots")
    assert_nil steps.prompt_folder
    run = start(steps, attach_logo(@interior, @customer))

    run.run!

    assert_equal [ "complete", nil ], [ run.reload.status, run.prompt_text ]
    file = run.generated_media.reload.file
    assert_equal [ "video", "video/mp4", "steps_#{run.id}.mp4" ], [ run.generated_media.kind, file.content_type, file.filename.to_s ]
    duration = file.open { Open3.capture2("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", it.path).first.to_f }
    assert_in_delta 2.0, duration, 0.1
  end

  { "doppler" => 9.6, "welcome" => 8.1, "black_eyed_peas" => 7.0, "azzurro" => 6.4, "gm_visuals" => 10.2 }.each do |kind, length|
    test "a #{kind} reel lays its track under its cuts" do
      run = start(Transformation.create!(name: kind, kind:), attach_logo(@interior, @customer))

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
    gm = Transformation.create!(name: "GM", kind: "gm_visuals")
    Dir.mktmpdir do |dir|
      clip = File.join(dir, "clip.mp4")
      system("ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=320x240:rate=30:duration=1", "-pix_fmt", "yuv420p", clip, exception: true)
      [ @interior, @customer ].each { it.update!(kind: "video", file: { io: StringIO.new(File.binread(clip)), filename: "clip.mp4", content_type: "video/mp4" }) }
    end
    run = start(gm, [ @interior, @customer ])

    run.run!

    assert_equal "complete", run.reload.status, run.error
    frames = run.generated_media.reload.file.open do
      Open3.capture2("ffprobe", "-v", "error", "-count_frames", "-select_streams", "v", "-show_entries", "stream=nb_read_frames", "-of", "csv=p=0", it.path).first.to_i
    end
    assert_equal (10.194 * 30).round, frames
  end

  test "a reel overlays its first cuts with its type's layer, each filled from its own step" do
    reel = Transformation.create!(name: "Black eyed peas", kind: "black_eyed_peas",
      layer_steps: [ { "line2" => "coffee" }, { "line1" => "", "line2" => "" }, { "line1" => "Our", "line2" => "tools" }, { "line2" => "" } ])
    assert_equal [ { "line2" => "coffee" }, {}, { "line1" => "Our", "line2" => "tools" }, {} ], reel.layer_steps
    png, htmls = file_fixture("logo.png").binread, []
    Layer.define_singleton_method(:screenshot) { |html, size:| htmls << html and png }

    run = start(reel, attach_logo(@interior, @customer))
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

  test "a prompt folder needs a prompt from it, and paints the prompt and its fixed style after the body" do
    prompts = []
    RubyLLM.define_singleton_method(:paint) do |prompt, **|
      prompts << prompt
      RubyLLM::Image.new(data: Base64.strict_encode64("jpeg-bytes"))
    end
    style = Style.create!(name: "Film", body: "35mm grain.")
    @collage.update!(prompt_folder: "Shots", style:)
    prompt = Prompt.create!(name: "Empty Chair", body: "The empty chair.", folder: "Shots")
    other = Prompt.create!(name: "Red Carpet", body: "A premiere.", folder: "Events")
    media = [ @interior, @customer ]

    assert_raises(ActiveRecord::RecordInvalid) { start(@collage, media) }
    assert_raises(ActiveRecord::RecordInvalid) { start(@collage, media, prompt: other) }
    run = start(@collage, media, prompt:)
    run.run!

    assert_equal [ "Compose a collage.\n\nThe empty chair.\n\n35mm grain." ], prompts
    assert_equal [ prompts.first, prompt, style ], [ run.reload.prompt_text, run.prompt, run.style ]
  end

  test "a type drops the inputs it doesn't take, and is fixed once saved" do
    style = Style.create!(name: "Film", body: "35mm grain.")
    review = Transformation.create!(name: "Reviews", kind: "review", style:, prompt_folder: "Shots")
    assert_equal [ nil, nil, true, "review" ], [ review.style, review.prompt_folder, review.takes_review?, review.layer.slug ]

    image = Transformation.create!(name: "Collage", kind: "generate_image", body: "x", style:, prompt_folder: "Shots")
    assert_equal [ style, "Shots", false, nil ], [ image.style, image.prompt_folder, image.takes_review?, image.layer ]

    assert_not review.update(kind: "generate_image")
    assert_includes review.errors.full_messages, "Kind can't be changed"
    assert_equal "review", review.reload.kind
  end

  test "a known type fixes its layer" do
    assert_equal [ "fully-booked-color", "Overlay · Fully booked" ], Transformation.new(kind: "fully_booked").then { [ it.layer.slug, it.type_label ] }
    assert_nil Transformation.new(kind: "steps").layer
    assert Transformation.new(name: "x", kind: "daily").valid?
    assert_not Transformation.new(name: "x", kind: "scripted").valid?
    assert_not Transformation.new(name: "x", kind: "nope").valid?
  end

  test "run! records a failure" do
    RubyLLM.define_singleton_method(:paint) { |*, **| raise RubyLLM::Error, "content policy" }
    run = start(@collage, [ @interior, @customer ])

    run.run!

    assert_equal [ "failed", "content policy" ], [ run.reload.status, run.error ]
    assert_not run.generated_media.reload.file.attached?
  end

  test "gemini options become Nano Banana imageConfig and Veo parameters" do
    RubyLLM::ActiveRecord::Model.create!(provider: "gemini", model_id: "gemini-3-pro-image", name: "Nano Banana Pro", enabled: true,
      modalities: { "input" => %w[text image], "output" => %w[text image] })
    RubyLLM::ActiveRecord::Model.create!(provider: "gemini", model_id: "veo-3.1-generate-preview", name: "Veo 3.1", enabled: true,
      modalities: { "input" => %w[text image], "output" => %w[video] })

    image = @collage.runs.new(options: { "model" => "gemini-3-pro-image", "aspect_ratio" => "4:5", "resolution" => "4k" })
    assert_equal({ model: "gemini-3-pro-image", generationConfig: { imageConfig: { aspectRatio: "4:5", imageSize: "4K" } }, provider: :gemini },
      image.ai_options)

    video = transformations(:cinematic).runs.new(options: { "model" => "veo-3.1-generate-preview", "resolution" => "1080p" })
    assert_equal({ model: "veo-3.1-generate-preview", parameters: { aspectRatio: "9:16", resolution: "1080p", durationSeconds: 8 }, provider: :gemini },
      video.ai_options)
  end

  test "an overlay renders its layer for today over the photo into its output folder" do
    feature = Transformation.create!(name: "Fully booked", kind: "fully_booked")
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user,
      file: { io: file_fixture("logo.png").open, filename: "ready.png", content_type: "image/png" })
    rendered = stub_screenshot

    assert_raises(ActiveRecord::RecordInvalid) { feature.run!(media: [ photo ], folder: folders(:photobank_logo), user: users(:admin_user)) }
    run = feature.run!(media: [ photo ], folder: folders(:photobank_logo))
    run.run!

    html, size = rendered.sole
    assert_equal [ 1080, 1920 ], size
    assert_includes html, "background-image: url(data:image/jpeg;base64,"
    assert_includes html, Date.current.strftime("%-d %B")
    media = run.reload.generated_media
    assert_equal [ "complete", nil, "photo", folders(:photobank_logo), [ photo ] ], [ run.status, run.prompt_text, media.kind, media.folder, run.source_media ]
    assert_equal [ "image/png", "png-bytes" ], [ media.file.content_type, media.file.download ]
  end

  test "an overlay fills its layer from its layer step" do
    text = Transformation.create!(name: "Text", kind: "text", layer_steps: [ { "text" => "Open late tonight" } ])
    rendered = stub_screenshot

    start(text, [ attach_logo(@interior).first ]).run!

    assert_includes rendered.sole.first, "Open late tonight"
    assert_empty Transformation.create!(name: "Reviews", kind: "review", layer_steps: [ { "text" => "x" } ]).layer_steps
  end

  test "an overlay over a video lays its transparent layer over the video, as a video" do
    feature = Transformation.create!(name: "Daily", kind: "daily")
    clip = Tempfile.new([ "clip", ".mp4" ])
    Open3.capture2e("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=320x240:duration=1:rate=30", "-pix_fmt", "yuv420p", clip.path)
    video = LibraryMedia.create!(kind: "video", folder: folders(:ready), user: @user,
      file: { io: File.open(clip.path), filename: "clip.mp4", content_type: "video/mp4" })
    assert feature.takes?(video)
    assert_not @collage.takes?(video)
    png, htmls = file_fixture("logo.png").binread, []
    Layer.define_singleton_method(:screenshot) { |html, size:| htmls << html and png }

    run = start(feature, [ video ])
    run.run!

    assert_equal "complete", run.reload.status, run.error
    assert_not_includes htmls.sole, "background-image: url("
    media = run.generated_media.reload
    assert_equal [ "video", "video/mp4" ], [ media.kind, media.file.content_type ]
    probe = media.file.open { Open3.capture2("ffprobe", "-v", "error", "-show_entries", "stream=width,height:format=duration", "-of", "csv=p=0", it.path).first }
    assert_equal "1080,1920", probe.lines.first.strip
    assert_in_delta 1.0, probe.lines.last.to_f, 0.1
  end

  test "smart crop takes one photo or video and makes the same, 9:16 at 1080x1920 around its subject" do
    assert_equal "Transform · Smart crop", Transformation.new(kind: "smart_crop").type_label
    assert_equal "Transform · Smart crop", Transformation.new(kind: "smart_crop").options_label
    crop = Transformation.create!(name: "Smart crop", kind: "smart_crop")
    # A red box on the left of a black frame: the middle 9:16 is all black.
    scene = "color=c=black:size=640x360:duration=1:rate=30,drawbox=x=20:y=130:w=100:h=100:color=red:t=fill"
    clip, still = Tempfile.new([ "clip", ".mp4" ]), Tempfile.new([ "still", ".png" ])
    system("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", scene, "-f", "lavfi", "-i", "sine=duration=1",
      "-pix_fmt", "yuv420p", "-shortest", clip.path, exception: true)
    system("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", scene, "-frames:v", "1", still.path, exception: true)
    video = LibraryMedia.create!(kind: "video", folder: folders(:ready), user: @user, file: { io: File.open(clip.path), filename: "clip.mp4", content_type: "video/mp4" })
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user, file: { io: File.open(still.path), filename: "still.png", content_type: "image/png" })

    [ [ video, "video", "video/mp4", 2 ], [ photo, "photo", "image/jpeg", 1 ] ].each do |source, kind, content_type, streams|
      run = crop.run!(media: [ source ], folder: folders(:photobank_logo))
      run.run!

      assert_equal "complete", run.reload.status, run.error
      media = run.generated_media.reload
      assert_equal [ kind, content_type ], [ media.kind, media.file.content_type ]
      probe = media.file.open { Open3.capture2("ffprobe", "-v", "error", "-show_entries", "stream=width,height", "-of", "csv=p=0", it.path).first }
      assert_equal [ "1080,1920", streams ], [ probe.lines.first.strip, probe.lines.size ]
      red = media.file.open do |file|
        frame = kind == "video" ? Open3.capture2("ffmpeg", "-loglevel", "error", "-i", file.path, "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-").first : File.binread(file.path)
        Vips::Image.new_from_buffer(frame, "")[0].avg
      end
      assert_operator red, :>, 10, "#{kind} crop missed the red box"
    end
  end

  test "zoom makes a 9:16 video of its duration zooming on the center of one photo or video, a video's sound kept" do
    zoom = Transformation.create!(name: "Zoom", kind: "zoom")
    assert_equal({ "zoom" => "in", "duration" => "1" }, zoom.options)
    assert_equal "Zoom in · 1 s", zoom.options_label
    assert_not zoom.update(options: { "zoom" => "in", "duration" => "9" })
    zoom.reload
    # A red box in the middle of a black frame: it grows as the zoom goes in.
    scene = "color=c=black:size=640x360:duration=3:rate=30,drawbox=x=290:y=150:w=60:h=60:color=red:t=fill"
    clip, still = Tempfile.new([ "clip", ".mp4" ]), Tempfile.new([ "still", ".png" ])
    system("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", scene, "-f", "lavfi", "-i", "sine=duration=3",
      "-pix_fmt", "yuv420p", "-shortest", clip.path, exception: true)
    system("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", scene, "-frames:v", "1", still.path, exception: true)
    video = LibraryMedia.create!(kind: "video", folder: folders(:ready), user: @user, file: { io: File.open(clip.path), filename: "clip.mp4", content_type: "video/mp4" })
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user, file: { io: File.open(still.path), filename: "still.png", content_type: "image/png" })

    [ [ photo, "in", "1", 1 ], [ video, "out", "2", 2 ] ].each do |source, direction, seconds, streams|
      zoom.update!(options: { "zoom" => direction, "duration" => seconds })
      run = zoom.run!(media: [ source ], folder: folders(:photobank_logo))
      run.run!

      assert_equal "complete", run.reload.status, run.error
      media = run.generated_media.reload
      assert_equal [ "video", "video/mp4" ], [ media.kind, media.file.content_type ]
      probe, (first, last) = media.file.open do |file|
        [ Open3.capture2("ffprobe", "-v", "error", "-show_entries", "stream=width,height:format=duration", "-of", "csv=p=0", file.path).first,
          [ %w[-ss 0], %w[-sseof -0.1] ].map do |seek|
            frame = Open3.capture2("ffmpeg", "-loglevel", "error", *seek, "-i", file.path, "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-").first
            Vips::Image.new_from_buffer(frame, "")[0].avg
          end ]
      end
      assert_equal [ "1080,1920", streams ], [ probe.lines.first.strip, probe.lines.size - 1 ]
      assert_in_delta seconds.to_f, probe.lines.last.to_f, 0.1
      assert_operator direction == "in" ? last : first, :>, (direction == "in" ? first : last) * 1.5, "zoom #{direction} went the wrong way"
    end
  end

  test "color grade puts one photo or video through its look's LUTs and makes the same, a video's sound kept" do
    grade = Transformation.create!(name: "Color grade", kind: "color_grade")
    assert_equal({ "look" => "kodak_2383" }, grade.options)
    assert_equal "Kodak 2383", grade.options_label
    assert_not grade.update(options: { "look" => "teal_orange" })
    grade.reload
    scene = "color=c=gray:size=320x240:duration=1:rate=30"
    clip, still = Tempfile.new([ "clip", ".mp4" ]), Tempfile.new([ "still", ".png" ])
    system("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", scene, "-f", "lavfi", "-i", "sine=duration=1",
      "-pix_fmt", "yuv420p", "-shortest", clip.path, exception: true)
    system("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", scene, "-frames:v", "1", still.path, exception: true)
    video = LibraryMedia.create!(kind: "video", folder: folders(:ready), user: @user, file: { io: File.open(clip.path), filename: "clip.mp4", content_type: "video/mp4" })
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user, file: { io: File.open(still.path), filename: "still.png", content_type: "image/png" })
    source = Vips::Image.new_from_file(still.path).avg

    [ [ photo, "kodak_2393", "photo", "image/jpeg", 1 ], [ video, "fujifilm_3510", "video", "video/mp4", 2 ] ].each do |media, look, kind, content_type, streams|
      grade.update!(options: { "look" => look })
      run = grade.run!(media: [ media ], folder: folders(:photobank_logo))
      run.run!

      assert_equal "complete", run.reload.status, run.error
      graded = run.generated_media.reload
      assert_equal [ kind, content_type ], [ graded.kind, graded.file.content_type ]
      probe, average = graded.file.open do |file|
        frame = kind == "video" ? Open3.capture2("ffmpeg", "-loglevel", "error", "-i", file.path, "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-").first : File.binread(file.path)
        [ Open3.capture2("ffprobe", "-v", "error", "-show_entries", "stream=width,height", "-of", "csv=p=0", file.path).first,
          Vips::Image.new_from_buffer(frame, "").avg ]
      end
      assert_equal [ "320,240", streams ], [ probe.lines.first.strip, probe.lines.size ]
      assert_operator (average - source).abs, :>, 3, "#{look} left the #{kind} ungraded"
    end
  end

  test "a review needs a review and renders it on its layer" do
    feature = Transformation.create!(name: "Reviews", kind: "review")
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @user,
      file: { io: file_fixture("logo.png").open, filename: "ready.png", content_type: "image/png" })
    review = @user.reviews.create!(source: "google", customer_name: "Dana K.", rating: 5, body: "Best fade in town.",
      avatar: { io: file_fixture("logo.png").open, filename: "dana.png", content_type: "image/png" })
    @user.reviews.create!(source: "google", customer_name: "Meh", rating: 4, body: "Fine.")
    rendered = stub_screenshot

    assert_equal [ review ], @user.reviews.postable.to_a
    assert_raises(ActiveRecord::RecordInvalid) { start(feature, [ photo ]) }
    assert_raises(ActiveRecord::RecordInvalid) { start(feature, [ photo ], review: users(:admin_user).reviews.create!(source: "google", customer_name: "X", rating: 5, body: "Hi.")) }
    run = start(feature, [ photo ], review:)
    run.run!

    html, = rendered.sole
    assert_equal [ "complete", review ], [ run.reload.status, run.review ]
    assert_includes html, "Best fade in town."
    assert_includes html, "Dana K."
    assert_includes html, %(src="data:image/jpeg;base64,)
  end

  private

    def start(transformation, media, **) = transformation.run!(media:, folder: folders(:ready), **)

    def attach_logo(*media) = media.each { it.file.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png") }

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
