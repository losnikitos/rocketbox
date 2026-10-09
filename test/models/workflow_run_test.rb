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
      { transformation: Transformation.create!(name: "Smart crop", kind: "smart_crop"), tag_ids: [ tags(:after).id ] }, { folder: folders(:photobank_logo) } ]
      .map { workflow.nodes.create!(it) }
    [ [ folder, generate ], [ generate, crop ], [ crop, output ] ].each { |from, to| workflow.edges.create!(from:, to:) }
    run = workflow.latest_run

    run.start!(folder, user)
    first = run.step_runs.sole
    assert_equal [ generate, [ newest ], folders(:ready) ], [ first.workflow_node, first.source_media, first.generated_media.folder ]

    first.generated_media.file.attach(io: StringIO.new("mp4"), filename: "a.mp4", content_type: "video/mp4")
    first.update!(status: "complete")
    second = run.step_runs.reload.last
    assert_empty first.generated_media.tags
    assert_equal [ crop, [ first.generated_media ], folders(:photobank_logo), [ tags(:after) ] ],
      [ second.workflow_node, second.source_media, second.generated_media.folder, second.generated_media.tags.order(:name).to_a ]
    assert_nil run.reload.error
    assert_equal [ [ newest ], [ second.generated_media ] ], [ run.inputs, run.outputs ]

    assert_no_difference -> { LibraryMedia.count } do
      run.start!(folder, user)
    end
    assert_equal [ first, second ], run.step_runs.reload

    second.update!(status: "complete")
    output.update!(folder: folders(:photobank_misc))
    crop.update!(tag_ids: [ tags(:before).id ])
    WorkflowRun.find(run.id).start!(folder, user)
    assert_equal [ first, second ], run.step_runs.reload
    assert_equal [ folders(:photobank_misc), [ tags(:after), tags(:before) ] ], second.generated_media.reload.then { [ it.folder, it.tags.order(:name).to_a ] }

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

  test "a new run reuses what another run made from the same media, sharing it, unless a step is forced to rerun" do
    user = users(:lazaro_nixon)
    user.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    workflow = Workflow.create!(name: "Reuse")
    folder, generate, crop = [ { folder: folders(:interior) }, { transformation: transformations(:cinematic) }, { transformation_attributes: { kind: "smart_crop" } } ]
      .map { workflow.nodes.create!(it) }
    [ [ folder, generate ], [ generate, crop ] ].each { |from, to| workflow.edges.create!(from:, to:) }
    complete = ->(step_run) { step_run.generated_media.file.attach(io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg") && step_run.update!(status: "complete") }
    first = workflow.latest_run
    first.start!(folder, user)
    complete.(first.step_runs.sole)
    complete.(first.step_runs.reload.last)
    made = first.step_runs.map(&:generated_media)

    second = workflow.runs.create!
    assert_no_difference -> { LibraryMedia.count } do
      second.start!(folder, user)
    end
    assert_equal [ made, first.step_runs.to_a, [ "complete" ] * 2 ], second.step_runs.then { [ it.map(&:generated_media), it.map(&:reused_from), it.map(&:status) ] }

    assert_difference -> { LibraryMedia.count } => 1 do
      second.rerun!(crop, user)
    end
    assert_not_equal made.last, second.step_runs.reload.last.generated_media
    assert LibraryMedia.exists?(made.last.id)

    first.destroy!
    assert_equal made.first, second.step_runs.first.generated_media.reload
    assert_nil second.step_runs.first.reused_from
  end

  test "a folder's newest media each get a step run, and a reel takes them all once complete, slot by slot, rerunning only a new one's" do
    user = users(:lazaro_nixon)
    photo = ->(folder, created_at) { user.library_media.create!(kind: "photo", folder: folders(folder), created_at:, file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" }) }
    photo.(:exterior, 2.days.ago)
    older, newer, inside = photo.(:exterior, 1.day.ago), photo.(:exterior, 1.hour.ago), photo.(:interior, 1.hour.ago)
    workflow = Workflow.create!(name: "Batch")
    interior, exterior, crop, reel = [ { folder: folders(:interior) }, { folder: folders(:exterior), take: 2 },
      { transformation_attributes: { kind: "smart_crop" } }, { transformation_attributes: { kind: "gm_visuals" } } ].map { workflow.nodes.create!(it) }
    assert_not workflow.edges.new(from: interior, to: reel).valid?
    [ [ interior, reel, "interior" ], [ exterior, crop, nil ], [ crop, reel, "exterior" ] ].each { |from, to, slot| workflow.edges.create!(from:, to:, slot:) }
    run = workflow.latest_run
    complete = ->(step_run) { step_run.generated_media.file.attach(io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg") && step_run.update!(status: "complete") }

    run.start!(exterior, user)
    crops = run.step_runs.to_a
    assert_equal [ [ newer ], [ older ] ], crops.map(&:source_media)

    complete.(crops.first)
    assert_equal crops, run.step_runs.reload
    complete.(crops.last)
    assert_nil run.reload.error
    assert_equal [ reel, [ *crops.map(&:generated_media), inside ] ], run.step_runs.reload.last.then { [ it.workflow_node, it.source_media ] }

    newest = photo.(:exterior, 1.minute.ago)
    run.start!(exterior, user)
    runs = run.step_runs.reload
    assert_equal [ crops.first, crop, [ [ newer ], [ newest ] ] ], [ runs.first, runs.last.workflow_node, runs.map(&:source_media) ]
  end

  test "a start folder's pinned media replace its newest in every run, and resetting the pins goes back to them" do
    user = users(:lazaro_nixon)
    photo = ->(created_at) { user.library_media.create!(kind: "photo", folder: folders(:interior), created_at:, file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" }) }
    older, newest = photo.(1.day.ago), photo.(1.hour.ago)
    workflow = Workflow.create!(name: "Picks")
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation: transformations(:cinematic))
    workflow.edges.create!(from: folder, to: step)
    run = workflow.latest_run
    assert_equal "draft", run.state

    folder.update!(pinned_media_ids: [ older.id ])
    run.start!(folder, user)
    assert_equal [ [ older ] ], run.step_runs.map(&:source_media)
    assert_equal [ "started", "running" ], [ run.status, run.state ]
    assert_equal [ older ], workflow.runs.create!.picked(folder, user)
    assert_equal "#{folders(:interior).path} · 1 pinned", folder.label

    folder.update!(pinned_media_ids: [ "" ])
    run = WorkflowRun.find(run.id)
    run.start!(folder, user)
    assert_equal [ [ newest ] ], run.step_runs.reload.map(&:source_media)
  end

  test "a step dropped blank from an AI type doesn't start until it has a prompt" do
    user = users(:lazaro_nixon)
    user.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    workflow = Workflow.create!(name: "Blank")
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation_attributes: { kind: "generate_image" })
    workflow.edges.create!(from: folder, to: step)
    run = workflow.latest_run

    run.start!(folder, user)
    assert_equal "#{Transformation::GenerateImage.label}: Add a prompt.", run.reload.error
    assert_empty run.step_runs
  end
end
