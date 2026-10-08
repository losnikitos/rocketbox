# frozen_string_literal: true

require "test_helper"

class WorkflowRunTest < ActiveSupport::TestCase
  test "play runs the start folder's newest media through each step once the one before completes, and replay starts over" do
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

    assert_difference -> { LibraryMedia.count } => -1 do
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
