# frozen_string_literal: true

require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "autorun runs each media landing in a start folder through a run of its own, but not what the workflow made" do
    user = users(:lazaro_nixon)
    workflow = Workflow.create!(name: "Auto")
    start, crop, output = [ { folder: folders(:interior) }, { transformation: Transformation.create!(name: "Smart crop", kind: "smart_crop") },
      { folder: folders(:interior) } ].map { workflow.nodes.create!(it) }
    [ [ start, crop ], [ crop, output ] ].each { |from, to| workflow.edges.create!(from:, to:) }
    attach = ->(media) { media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg") }
    land = -> { user.library_media.create!(kind: "photo", folder: folders(:interior)).tap { attach.(it) } }

    perform_enqueued_jobs(only: AutorunWorkflowsJob) do
      assert_no_difference(-> { WorkflowRun.count }) { land.() }

      workflow.update!(autorun: true)
      media = land.()
      run = workflow.runs.sole
      step_run = run.step_runs.sole
      assert_equal [ "started", { start.id.to_s => [ media.id ] }, [ media ], folders(:interior) ],
        [ run.status, run.picks, step_run.source_media, step_run.generated_media.folder ]

      attach.(step_run.generated_media)
      assert_equal [ run ], workflow.runs.reload
    end
  end
end
