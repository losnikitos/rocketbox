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

  test "next_media picks the oldest never-posted media, then nothing" do
    a, b = 2.times.map { photo }
    @rubric.posts.create!(library_media: a)

    assert_equal b, @rubric.next_media
    @rubric.posts.create!(library_media: b)
    assert_nil @rubric.next_media
  end

  test "plan picks fresh media until none is left, and nothing from an empty folder" do
    travel_to Time.zone.local(2026, 1, 1, 8)
    assert_equal [ nil ] * 3, Rubric.plan([ @rubric ], 3.days.from_now).map(&:last)

    a, b = 2.times.map { photo }
    plan = Rubric.plan([ @rubric ], 3.days.from_now)
    assert_equal [ 1, 2, 3 ], plan.map { it.first.day }
    assert_equal [ a, b, nil ], plan.map(&:last)

    @rubric.posts.create!(library_media: a, scheduled_at: plan.first.first)
    plan = Rubric.plan([ @rubric ], 3.days.from_now)
    assert_equal [ 2, 3 ], plan.map { it.first.day }
    assert_equal [ b, nil ], plan.map(&:last)
  end

  test "tags narrow the folder to media with all of them" do
    travel_to Time.zone.local(2026, 1, 1, 8)
    plain, tagged = 2.times.map { photo }
    tagged.tags << tags(:before)
    @rubric.update!(tag_ids: [ tags(:before).id, "" ])

    assert_equal [ tags(:before).id ], @rubric.tag_ids
    assert_equal tagged, @rubric.next_media
    assert_equal [ tagged, nil ], Rubric.plan([ @rubric ], 2.days.from_now).map(&:last)
    assert_not @rubric.update(tag_ids: [ 0 ])
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

  test "a due rubric with nothing fresh skips and moves on" do
    @rubric.posts.create!(library_media: photo, scheduled_at: 1.day.ago)
    @rubric.update_columns(next_run_at: 1.minute.ago)

    assert_no_enqueued_jobs(only: PublishRubricPostJob) { @rubric.run! }
    assert_equal 1, @rubric.posts.count
    assert_operator @rubric.reload.next_run_at, :>, Time.current
  end

  test "a post already made for the due time goes out instead of a new one" do
    photo
    made = @rubric.posts.create!(scheduled_at: @rubric.next_run_at)
    travel_to(@rubric.next_run_at + 1.minute)

    assert_enqueued_with(job: PublishRubricPostJob, args: [ made ]) { @rubric.run! }
    assert_equal [ made ], @rubric.posts.to_a
  end

  private
    def photo
      @user.library_media.create!(kind: "photo", folder: folders(:ready),
        file: { io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg" })
    end
end
