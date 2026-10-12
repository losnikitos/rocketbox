# frozen_string_literal: true

require "test_helper"

class Accounts::JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @jobs = 2.times.map { @user.jobs.create!(created_at: it.minutes.from_now) }
    @media = @jobs.map { LibraryMedia.create!(kind: "photo", user: @user, job: it) }
  end

  test "lists jobs as pills and merges the checked ones" do
    get jobs_url
    assert_response :success
    assert_select "##{dom_id(@jobs.first)}", text: /job_1.*Job 1/m

    get library_folders_url(root: "inbox")
    assert_select "#folder-media-#{@media.first.id}", text: /job_1/

    post merge_jobs_url, params: { job_ids: @jobs.map(&:id) }
    assert_redirected_to jobs_url
    assert_equal "Merged into @job_1.", flash[:notice]
    assert_equal [ @jobs.first ], @user.jobs.reload.to_a
    assert_equal [ @jobs.first.id ], @media.map { it.reload.job_id }.uniq
  end

  test "won't merge fewer than two of the account's jobs" do
    other = users(:admin_user).jobs.create!
    post merge_jobs_url, params: { job_ids: [ @jobs.first.id, other.id ] }
    assert_redirected_to jobs_url
    assert_equal "Select at least two jobs to merge.", flash[:alert]
    assert Job.exists?(other.id)

    post merge_jobs_url
    assert_equal "Select at least two jobs to merge.", flash[:alert]
  end
end
