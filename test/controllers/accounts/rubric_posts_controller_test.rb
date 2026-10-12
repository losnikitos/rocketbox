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
end
