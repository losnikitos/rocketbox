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

  test "starts_for finds the start folders a media is in with all their tags" do
    assert_equal "new-tag", Tag.create!(name: " #New-Tag ").name
    workflow = Workflow.create!(name: "Crop")
    plain, tagged, output = [ { folder: folders(:interior) }, { folder: folders(:interior), tag_ids: [ tags(:before).id ] },
      { folder: folders(:ready) } ].map { workflow.nodes.create!(it) }
    image = workflow.nodes.create!(transformation: Transformation.create!(name: "Image", kind: "generate_image"))
    [ [ plain, image ], [ tagged, image ], [ image, output ] ].each { |from, to| workflow.edges.create!(from:, to:) }
    media = users(:lazaro_nixon).library_media.create!(kind: "photo", folder: folders(:interior))

    assert_equal [ [ workflow, plain ] ], Workflow.starts_for(media)
    media.tags << tags(:before)
    assert_equal [ [ workflow, plain ], [ workflow, tagged ] ], Workflow.starts_for(media.reload)
    assert_empty Workflow.starts_for(users(:lazaro_nixon).library_media.create!(kind: "photo", folder: folders(:ready)))
  end

  test "a start folder's media type filters what it takes and gives" do
    workflow = Workflow.create!(name: "Types")
    images, videos = %w[image video].map { workflow.nodes.create!(folder: folders(:interior), media_type: it) }
    image = workflow.nodes.create!(transformation: Transformation.create!(name: "Image", kind: "generate_image"))
    [ images, videos ].each { workflow.edges.create!(from: it, to: image) }
    user = users(:lazaro_nixon)
    photo = user.library_media.create!(kind: "document", folder: folders(:interior))
    photo.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    assert_equal [ [ workflow, images ] ], Workflow.starts_for(photo)
    run = workflow.runs.create!
    assert_equal [ [ photo ], [] ], [ run.picked(images, user), run.picked(videos, user) ]
    assert_not workflow.nodes.build(folder: folders(:interior), media_type: "audio").valid?
    assert_nil workflow.nodes.build(media_type: "").media_type
  end

  test "a note stands alone, blank or not, and connects to nothing" do
    workflow = Workflow.create!(name: "Notes")
    note = workflow.nodes.create!(note: "")
    crop = workflow.nodes.create!(transformation: Transformation.create!(name: "Smart crop", kind: "smart_crop"))
    assert_equal [ "amber", "Note" ], [ note.color, note.label ]
    assert_not workflow.nodes.build(note: "Hi", folder: folders(:interior)).valid?
    assert_not workflow.nodes.build(note: "Hi", color: "pink").valid?
    assert_equal [ "Notes don't connect." ], workflow.edges.build(from: crop, to: note).tap(&:validate).errors[:base]
  end

  test "slug follows the name, and an old slug still finds it" do
    workflow = Workflow.create!(name: "Inbox to ready")
    assert_equal "inbox-to-ready", workflow.to_param
    workflow.update!(name: "2026")
    assert_equal [ "workflow-2026", workflow, workflow ], [ workflow.slug, Workflow.find("inbox-to-ready"), Workflow.find(workflow.id) ]
  end
end
