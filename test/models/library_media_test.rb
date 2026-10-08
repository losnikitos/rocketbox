# frozen_string_literal: true

require "test_helper"

class LibraryMediaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "videos get a pre-rendered thumb on upload" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "clip.mp4")
      system("ffmpeg", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=d=1:s=320x240", "-pix_fmt", "yuv420p", path, exception: true)
      media = perform_enqueued_jobs do
        LibraryMedia.create!(kind: "video", user: users(:lazaro_nixon),
          file: { io: File.open(path), filename: "clip.mp4", content_type: "video/mp4" })
      end

      preview = media.file.blob.reload.preview_image
      assert preview.attached?
      assert preview.variant_records.any?
    end
  end
  test "kind_for maps content types" do
    assert_equal "photo", LibraryMedia.kind_for("image/jpeg")
    assert_equal "video", LibraryMedia.kind_for("video/mp4")
    assert_equal "audio", LibraryMedia.kind_for("audio/mpeg")
    assert_equal "document", LibraryMedia.kind_for("application/pdf")
  end

  test "allows web uploads without channel identity" do
    media = LibraryMedia.create!(kind: "photo", user: users(:lazaro_nixon))
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    assert media.persisted?
    assert_nil media.telegram_file_id
    assert_nil media.whatsapp_media_id
  end

  test "generated media are versions of the first input only" do
    user = users(:lazaro_nixon)
    source, extra, result = 3.times.map { LibraryMedia.create!(kind: "photo", user:) }
    TransformationRun.create!(generated_media: result, status: "complete",
      inputs: [ TransformationRunInput.new(library_media: source, position: 0), TransformationRunInput.new(library_media: extra, position: 1) ])

    assert_equal [ result ], source.generated_media.to_a
    assert_empty extra.generated_media
  end
end
