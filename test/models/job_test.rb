# frozen_string_literal: true

require "test_helper"

class JobTest < ActiveSupport::TestCase
  setup { @user = users(:lazaro_nixon) }

  test "numbers default names per account and slugs them once" do
    first = @user.jobs.create!
    assert_equal [ "Job 1", "job_1" ], [ first.name, first.slug ]
    assert_equal "job_2", @user.jobs.create!.slug
    assert_equal "job_1", users(:admin_user).jobs.create!.slug

    first.destroy!
    assert_equal "job_1", @user.jobs.create!.slug
    first = @user.jobs.find_by!(slug: "job_1")
    first.update!(name: "Marco")
    assert_equal "job_1", first.reload.slug
  end

  test "merge keeps the oldest job with every media and post" do
    jobs = 3.times.map { @user.jobs.create!(created_at: it.days.ago, posts_count: it) }
    media = jobs.map { LibraryMedia.create!(kind: "photo", user: @user, job: it) }

    kept = Job.merge!(jobs)
    assert_equal jobs.last, kept
    assert_equal media.sort_by(&:id), kept.library_media.sort_by(&:id)
    assert_equal 3, kept.reload.posts_count
    assert_equal [ kept ], @user.jobs.reload.to_a
  end

  test "media can't take another account's job" do
    media = LibraryMedia.new(kind: "photo", user: @user, job: users(:admin_user).jobs.create!)
    assert_not media.valid?
    assert_includes media.errors[:job], "belongs to another account"
  end
end
