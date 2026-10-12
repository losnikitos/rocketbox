# frozen_string_literal: true

require "test_helper"

class Accounts::JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @jobs = 2.times.map { @user.jobs.create!(created_at: it.minutes.from_now) }
    @media = @jobs.map { LibraryMedia.create!(kind: "photo", user: @user, job: it) }
  end

  test "lists jobs as pills with their media to drag between them or onto a new one" do
    get jobs_url
    assert_response :success
    assert_select "##{dom_id(@jobs.first)}[data-move-job='#{@jobs.first.id}']", text: /job_1.*Job 1/m
    assert_select "##{dom_id(@jobs.first)} a[draggable=true][data-move-url=?][data-move-from='#{@jobs.first.id}'][data-move-field='library_media[job_id]']",
      library_media_path(@media.first)
    assert_select "[data-move-job=new]", text: /new job/
    assert_select "form[data-drag-move-target=form]"
    assert_select "nav[aria-label=Secondary] a[aria-selected=true]", text: "Grid"

    get jobs_url(view: "list")
    assert_select "nav[aria-label=Secondary] a[aria-selected=true]", text: "List"
    assert_select "##{dom_id(@jobs.first)}[data-move-job='#{@jobs.first.id}']", text: /0 posts/
    assert_select "##{dom_id(@jobs.first)} a[draggable=true][data-move-from='#{@jobs.first.id}']"

    get library_folders_url(root: "inbox")
    assert_select "#folder-media-#{@media.first.id}", text: /job_1/
  end
end
