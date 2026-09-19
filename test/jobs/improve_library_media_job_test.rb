# frozen_string_literal: true

require "test_helper"

class ImproveLibraryMediaJobTest < ActiveJob::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @media = LibraryMedia.create!(
      telegram_file_id: "f2",
      telegram_file_unique_id: "u2-improve-job",
      kind: "photo",
      user: @user
    )
    @media.file.attach(
      io: StringIO.new("fake-image"),
      filename: "shot.jpg",
      content_type: "image/jpeg"
    )
  end

  test "calls ImproveLibraryMedia with media" do
    called_with = nil
    original = ImproveLibraryMedia.method(:call)
    ImproveLibraryMedia.define_singleton_method(:call) do |**kwargs|
      called_with = kwargs
      true
    end

    ImproveLibraryMediaJob.perform_now(@media.id)

    assert_equal @media, called_with[:media]
  ensure
    ImproveLibraryMedia.define_singleton_method(:call, original)
  end
end
