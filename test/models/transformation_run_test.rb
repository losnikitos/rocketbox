# frozen_string_literal: true

require "test_helper"

class TransformationRunTest < ActiveSupport::TestCase
  test "recent_for lists the user's last 5 recipe runs, newest first, without manual versions" do
    user = users(:lazaro_nixon)
    runs = 6.times.map { |i| make_run(user, recipes(:cinematic), created_at: i.hours.ago) }
    make_run(user, nil)
    make_run(users(:admin_user), recipes(:cinematic))

    assert_equal runs.first(5), TransformationRun.recent_for(user).to_a
  end

  test "a transformation runs without a recipe into the given folder, still taking only media it can" do
    user = users(:lazaro_nixon)
    transformation = transformations(:cinematic)
    photo = LibraryMedia.create!(kind: "photo", folder: folders(:inbox), user:, file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    document = LibraryMedia.create!(kind: "document", folder: folders(:inbox), user:, file: { io: StringIO.new("pdf"), filename: "a.pdf", content_type: "application/pdf" })

    assert_raises(ActiveRecord::RecordInvalid) { transformation.run!(media: [ document ], folder: folders(:photobank_logo)) }
    assert_raises(ActiveRecord::RecordInvalid) { transformation.run!(media: [], folder: folders(:photobank_logo), user:) }
    run = transformation.run!(media: [ photo ], folder: folders(:photobank_logo), tags: [ tags(:after) ])

    assert_equal [ transformation, nil, [ photo ] ], [ run.transformation, run.recipe, run.source_media ]
    assert_equal [ folders(:photobank_logo), "video", [ tags(:after) ], "Slow cinematic push-in on the shop." ],
      [ run.generated_media.folder, run.generated_media.kind, run.generated_media.tags.to_a, run.prompt ]
  end

  private

    def make_run(user, recipe, created_at: Time.current)
      media = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user:)
      TransformationRun.new(recipe:, generated_media: media, created_at:).tap { it.save!(validate: false) }
    end
end
