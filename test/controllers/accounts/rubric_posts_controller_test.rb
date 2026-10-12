# frozen_string_literal: true

require "test_helper"

class Accounts::RubricPostsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "a scheduled post shows and publishes now, only for its owner" do
    user = sign_in_as(users(:lazaro_nixon))
    rubric = user.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready))
    post_ = rubric.posts.create!(scheduled_at: 1.day.from_now)

    get rubric_post_url(rubric, post_)
    assert_select "h2", /Morning story/
    assert_select "span", "Scheduled"
    assert_select "button", /Publish now/

    assert_enqueued_with(job: PublishRubricPostJob, args: [ post_ ]) { post publish_rubric_post_url(rubric, post_) }
    assert_redirected_to rubric_post_url(rubric, post_)
    assert_equal "publishing", post_.reload.status

    admin = sign_in_as(users(:admin_user))
    get rubric_post_url(rubric, post_, account: admin.id)
    assert_response :not_found
  end

  test "an admin gets the admin menu on a post, and deletes it" do
    owner = users(:lazaro_nixon)
    rubric = owner.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready))
    post_ = rubric.posts.create!(scheduled_at: 1.day.from_now)
    sign_in_as(users(:admin_user))

    get rubric_post_url(rubric, post_, account: owner.id)
    assert_select "a[href^=?]", admin_rubric_post_path(post_)
    get admin_rubric_post_url(post_)
    assert_response :success

    delete rubric_post_url(rubric, post_, account: owner.id)
    assert_redirected_to edit_rubric_url(rubric, account: owner.id)
    assert_not RubricPost.exists?(post_.id)
  end

  test "a planned calendar post locks in with its media, once and only at a planned time" do
    travel_to Time.zone.local(2026, 1, 1, 8)
    user = sign_in_as(users(:lazaro_nixon))
    rubric = user.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready), auto_publish: true)
    media = user.library_media.create!(kind: "photo", folder: folders(:ready),
      file: { io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg" })
    nine = Time.zone.local(2026, 1, 1, 9)

    get edit_rubric_url(rubric)
    assert_select "button[aria-label='Lock in this post']", 1

    post rubric_posts_url(rubric), params: { scheduled_at: nine.iso8601 }
    made = rubric.posts.sole
    assert_redirected_to rubric_post_url(rubric, made)
    assert_equal [ media, nine, "scheduled" ], [ made.library_media, made.scheduled_at, made.status ]

    [ nine, nine + 1.hour, "nonsense" ].each do |time|
      assert_no_difference("RubricPost.count") { post rubric_posts_url(rubric), params: { scheduled_at: time.try(:iso8601) || time } }
    end
  end
end
