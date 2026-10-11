# frozen_string_literal: true

require "test_helper"

class RubricTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:lazaro_nixon)
    @rubric = @user.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready), auto_publish: true)
  end

  test "schedule must parse and run at most hourly, in the app's zone" do
    assert_not @user.rubrics.new(name: "x", schedule: "whenever", folder: folders(:ready)).valid?
    assert_includes @user.rubrics.new(name: "x", schedule: "*/5 * * * *", folder: folders(:ready)).tap(&:valid?).errors[:schedule],
      "can't run more than once an hour"
    assert_equal 9, @rubric.next_run_at.in_time_zone.hour
    assert_equal 9, @user.rubrics.create!(name: "Cron", schedule: "0 9 * * 1-5", folder: folders(:ready)).next_run_at.in_time_zone.hour
  end

  test "next_media picks never-posted media, then the one posted longest ago" do
    a, b, c = 3.times.map { photo }
    travel_to(2.days.ago) { @rubric.posts.create!(library_media: b) }
    travel_to(1.day.ago) { @rubric.posts.create!(library_media: a) }

    assert_equal c, @rubric.next_media
    @rubric.posts.create!(library_media: c)
    assert_equal b, @rubric.next_media
  end

  test "due auto-publishing rubrics post their next media and move on" do
    media = photo
    off = @user.rubrics.create!(name: "Off", schedule: "every day at 9am", folder: folders(:ready))
    [ @rubric, off ].each { it.update_columns(next_run_at: 1.minute.ago) }

    assert_enqueued_with(job: PublishRubricPostJob) { PublishRubricsJob.perform_now }

    assert_equal [ media ], @rubric.posts.map(&:library_media)
    assert_operator @rubric.reload.next_run_at, :>, Time.current
    assert_empty off.posts
  end

  private
    def photo
      @user.library_media.create!(kind: "photo", folder: folders(:ready),
        file: { io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg" })
    end
end
