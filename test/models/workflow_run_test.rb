# frozen_string_literal: true

require "test_helper"

class WorkflowRunTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    recipe = Recipe.create!(name: "Bank holiday", workflow: "TwoPhotoStory", prompt: "Film look",
      texts: { "text_1" => "Open as usual", "text_2" => "Book now" })
    @post = @user.smm_posts.new(recipe:, status: "draft")
    2.times do |i|
      media = LibraryMedia.create!(kind: "photo", user: @user, file: { io: StringIO.new(jpeg), filename: "#{i}.jpg", content_type: "image/jpeg" })
      @post.smm_post_media_items.build(library_media: media, position: i)
    end
    @post.save!

    @original_paint = RubyLLM.method(:paint)
    @prompts = []
    @paint_options = []
    prompts, paint_options = @prompts, @paint_options
    stub_paint { |prompt, model:, provider_options:, **| prompts << prompt; paint_options << { model:, provider_options: }; jpeg }
  end

  teardown do
    RubyLLM.define_singleton_method(:paint, @original_paint)
  end

  test "runs every step and turns the output into story slides" do
    run = WorkflowRun.start!(@post)
    advance_until_settled(run)

    assert run.complete?
    assert_equal "ready", @post.reload.status
    assert_equal "story", @post.format
    assert_equal 2, @post.smm_slides.size
    assert_equal [ "Film look" ] * 2, @prompts
    slide = Vips::Image.new_from_buffer(@post.smm_slides.first.media.download, "")
    assert_equal [ 1080, 1920 ], [ slide.width, slide.height ]
    assert run.workflow_steps.all?(&:complete?)
  end

  test "pause stops between steps and resume continues" do
    run = WorkflowRun.start!(@post)
    run.advance!
    run.pause!
    run.advance!
    assert_equal 1, run.workflow_steps.count(&:complete?)

    run.resume!
    advance_until_settled(run)
    assert run.complete?
  end

  test "a failed step fails the run and retry picks up from it" do
    stub_paint { |*, **| raise RubyLLM::Error, "content policy" }
    run = WorkflowRun.start!(@post)
    advance_until_settled(run)

    assert run.failed?
    assert_equal "failed", @post.reload.status
    failed = run.workflow_steps.find(&:failed?)
    assert_equal "content policy", failed.error

    stub_paint { |*, **| jpeg }
    run.rerun!(failed.key)
    advance_until_settled(run)
    assert run.complete?
    assert_equal "ready", @post.reload.status
  end

  test "stop mid-step discards the step's result and re-run continues" do
    post = @post
    stub_paint { |*, **| WorkflowRun.find_by!(subject: post).stop!; jpeg }
    run = WorkflowRun.start!(@post)
    advance_until_settled(run)

    assert run.stopped?
    stopped = run.workflow_steps.find(&:failed?)
    assert_equal "Stopped.", stopped.error
    assert_not stopped.outputs.attached?

    stub_paint { |*, **| jpeg }
    run.rerun!(stopped.key)
    advance_until_settled(run)
    assert run.complete?
  end

  test "a generation turns its output into library media, without a post" do
    recipe = Recipe.create!(name: "Film", workflow: "ImageToImage", prompt: "Film look", media_type: "interior")
    source = LibraryMedia.create!(kind: "photo", user: @user, media_type: "interior",
      file: { io: StringIO.new(jpeg), filename: "room.jpg", content_type: "image/jpeg" })

    generation = source.generations.new(recipe:, options: { "resolution" => "2k", "quality" => "" })
    assert_no_difference(-> { SmmPost.count }) { generation.start! }
    media = generation.generated_media
    assert_equal [ @user, "photo", "photobank", "interior" ], [ media.user, media.kind, media.collection, media.media_type ]
    assert_not media.file.attached?
    assert_equal source, media.source_media

    advance_until_settled(generation.workflow_run)
    assert_equal "complete", generation.reload.status
    assert_equal [ { model: "grok-imagine-image-2.0", provider_options: { aspect_ratio: "3:4", resolution: "2k" } } ], @paint_options
    first_blob = media.reload.file.blob
    assert first_blob

    generation.workflow_run.rerun!("image")
    advance_until_settled(generation.workflow_run)
    assert_equal media, generation.reload.generated_media
    assert_not_equal first_blob, media.reload.file.blob
  end

  private

    def stub_paint(&block)
      RubyLLM.define_singleton_method(:paint) { |*args, **kwargs| RubyLLM::Image.new(data: Base64.strict_encode64(block.call(*args, **kwargs))) }
    end

    def advance_until_settled(run)
      20.times do
        run.reload.advance!
        break unless run.reload.running?
      end
    end

    def jpeg
      Vips::Image.black(40, 60).add(128).cast(:uchar).jpegsave_buffer
    end
end
