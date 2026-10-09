# frozen_string_literal: true

require "test_helper"

class TransformationRunTest < ActiveSupport::TestCase
  test "a transformation runs into the given folder with its tags, taking only media it can" do
    user = users(:lazaro_nixon)
    transformation = transformations(:cinematic)
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:inbox), user:, file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    document = LibraryMedia.create!(kind: "document", folder: folders(:inbox), user:, file: { io: StringIO.new("pdf"), filename: "a.pdf", content_type: "application/pdf" })

    assert_raises(ActiveRecord::RecordInvalid) { transformation.run!(media: [ document ], folder: folders(:photobank_logo)) }
    assert_raises(ActiveRecord::RecordInvalid) { transformation.run!(media: [], folder: folders(:photobank_logo), user:) }
    run = transformation.run!(media: [ photo ], folder: folders(:photobank_logo), tags: [ tags(:after) ])

    assert_equal [ transformation, nil, [ photo ] ], [ run.transformation, run.workflow_run, run.source_media ]
    assert_equal [ folders(:photobank_logo), "video", [ tags(:after) ], "Slow cinematic push-in on the shop." ],
      [ run.generated_media.folder, run.generated_media.kind, run.generated_media.tags.to_a, run.prompt ]
  end
end
