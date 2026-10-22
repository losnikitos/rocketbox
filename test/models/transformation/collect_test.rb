# frozen_string_literal: true

require "test_helper"

class Transformation::CollectTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:lazaro_nixon)
    @user.update!(whatsapp_phone: "15551234567")
    @folder = folders(:interior)
    @workflow = Workflow.create!(name: "Cuts", autorun: true)
    @start, @collect, @reel = [
      { folder: @folder },
      { transformation_attributes: { kind: "collect" } },
      { transformation_attributes: { kind: "gm_visuals", body: "We're preparing a reel" } }
    ].map { @workflow.nodes.create!(it) }
    [ [ @start, @collect ], [ @collect, @reel ] ].each { |from, to| @workflow.edges.create!(from:, to:) }
  end

  test "type waits, forwards both photos, and does not make a new media row" do
    type = Transformation::Collect
    assert_includes Transformation::Type.all, type
    assert type.waits?
    assert type.forwards?
    assert_equal({ image: 1.. }, type.inputs)
    assert Rails.root.join("app/assets/images", type.cover).exist?
  end

  test "the second photo joins the waiting run, then the reel gets both in order" do
    sent = []
    original = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }

    perform_enqueued_jobs(only: AutorunWorkflowsJob) do
      first = photo("before")
      run = @workflow.runs.sole
      waiting = run.step_runs.sole
      assert_equal [ "waiting", [ first ], 0 ], [ waiting.status, waiting.source_media, sent.size ]

      second = nil
      # The new photo, plus the reel's result row. Collect itself adds none: its result is the first photo.
      assert_no_difference -> { @workflow.runs.count } do
        assert_difference -> { LibraryMedia.count } => 2 do
          second = photo("after")
        end
      end

      waiting.reload
      assert_equal "complete", waiting.status
      assert_equal [ first, second ], waiting.source_media
      assert_equal first, waiting.result
      reel = run.step_runs.reload.last
      assert_equal [ @reel, [ first, second ], "running" ], [ reel.workflow_node, reel.source_media, reel.status ]
      assert_equal [ "We're preparing a reel" ], sent
    end
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original) if original
  end

  test "a photo in another folder does not join the open collect" do
    perform_enqueued_jobs(only: AutorunWorkflowsJob) do
      photo("before")
      photo("elsewhere", folders(:exterior))
    end

    waiting = @workflow.runs.sole.step_runs.sole
    assert_equal "waiting", waiting.status
    assert_equal 1, waiting.source_media.size
  end

  private

    def photo(name, folder = @folder)
      @user.library_media.create!(kind: "photo", folder:, file: {
        io: StringIO.new(name), filename: "#{name}.jpg", content_type: "image/jpeg"
      })
    end
end
