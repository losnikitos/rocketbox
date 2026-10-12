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

  test "a job left without media folds its posts into the job its last media moved to" do
    from, to = [ 3, 1 ].map { @user.jobs.create!(posts_count: it) }
    media = 2.times.map { LibraryMedia.create!(kind: "photo", user: @user, job: from) }

    media.first.update!(job: to)
    assert_equal [ 3, 1 ], [ from.reload.posts_count, to.reload.posts_count ]

    media.last.update!(job: to)
    assert_not Job.exists?(from.id)
    assert_equal 4, to.reload.posts_count

    media.each { it.update!(job: nil) }
    assert_not Job.exists?(to.id)
  end

  test "media can't take another account's job" do
    media = LibraryMedia.new(kind: "photo", user: @user, job: users(:admin_user).jobs.create!)
    assert_not media.valid?
    assert_includes media.errors[:job], "belongs to another account"
  end
end
