# frozen_string_literal: true

require "test_helper"

class LibraryMediaTest < ActiveSupport::TestCase
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
end
