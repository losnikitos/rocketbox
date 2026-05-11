# frozen_string_literal: true

require "test_helper"

class SubscriptionFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "subscribe enqueues mail and redirects to thanks" do
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post subscription_path, params: { subscription_request: { email: "NEW@Example.com " } }
    end
    assert_redirected_to subscription_thanks_path
  end

  test "invalid email returns errors" do
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      post subscription_path, params: { subscription_request: { email: "not-an-email" } }
    end
    assert_response :unprocessable_entity
  end

  test "valid subscription token redirects to sign up with email prefilled" do
    token = SubscriptionLink.generate!("reader@example.com")

    get subscription_access_url(t: token)
    assert_redirected_to sign_up_path(email_hint: "reader@example.com")
  end

  test "invalid subscription token redirects to request form" do
    get subscription_access_url(t: "invalid")
    assert_redirected_to new_subscription_path
  end
end
