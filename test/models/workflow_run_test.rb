# frozen_string_literal: true

require "test_helper"

class WorkflowRunTest < ActiveSupport::TestCase
  test "play runs the start folder's newest media through each step once the one before completes, and replay reruns only what changed" do
    user = users(:lazaro_nixon)
    photo = ->(created_at) { user.library_media.create!(kind: "photo", folder: folders(:interior), created_at:, file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" }) }
    photo.(1.day.ago)
    newest = photo.(1.hour.ago)
    workflow = Workflow.create!(name: "Chain")
    folder, generate, crop, output = [ { folder: folders(:interior) }, { transformation: transformations(:cinematic) },
      { transformation: Transformation.create!(name: "Smart crop", kind: "smart_crop") }, { folder: folders(:photobank_logo), tag: tags(:after) } ]
      .map { workflow.nodes.create!(it) }
    [ [ folder, generate ], [ generate, crop ], [ crop, output ] ].each { |from, to| workflow.edges.create!(from:, to:) }
    run = workflow.draft_run

    run.start!(folder, user)
    first = run.step_runs.sole
    assert_equal [ generate, [ newest ], folders(:ready) ], [ first.workflow_node, first.source_media, first.generated_media.folder ]

    first.generated_media.file.attach(io: StringIO.new("mp4"), filename: "a.mp4", content_type: "video/mp4")
    first.update!(status: "complete")
    second = run.step_runs.reload.last
    assert_equal [ crop, [ first.generated_media ], folders(:photobank_logo), [ tags(:after) ] ],
      [ second.workflow_node, second.source_media, second.generated_media.folder, second.generated_media.tags.to_a ]
    assert_nil run.reload.error

    assert_no_difference -> { LibraryMedia.count } do
      run.start!(folder, user)
    end
    assert_equal [ first, second ], run.step_runs.reload

    second.update!(status: "complete")
    output.update!(folder: folders(:photobank_misc), tag: nil)
    WorkflowRun.find(run.id).start!(folder, user)
    assert_equal [ first, second ], run.step_runs.reload
    assert_equal [ folders(:photobank_misc), [ tags(:after) ] ], second.generated_media.reload.then { [ it.folder, it.tags.to_a ] }

    crop.transformation.touch
    run.start!(folder, user)
    assert_equal [ first, crop ], run.step_runs.reload.then { [ it.first, it.last.workflow_node ] }
    assert_not TransformationRun.exists?(second.id)

    run.step_runs.last.update!(status: "complete")
    assert_difference -> { LibraryMedia.count } => -1 do
      run.rerun!(generate, user)
    end
    assert_equal [ generate ], run.step_runs.reload.map(&:workflow_node)
    assert_not TransformationRun.exists?(first.id)

    photo.(1.minute.ago)
    assert_no_difference -> { LibraryMedia.count } do
      run.start!(folder, user)
    end
    assert_equal [ generate ], run.step_runs.reload.map(&:workflow_node)
  end

  test "a step dropped blank from an AI type doesn't start until it has a prompt" do
    user = users(:lazaro_nixon)
    user.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    workflow = Workflow.create!(name: "Blank")
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation_attributes: { kind: "generate_image" })
    workflow.edges.create!(from: folder, to: step)
    run = workflow.draft_run

    run.start!(folder, user)
    assert_equal "#{Transformation::GenerateImage.label}: Add a prompt.", run.reload.error
    assert_empty run.step_runs
  end
end
