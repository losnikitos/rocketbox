# frozen_string_literal: true

require "test_helper"

class FreePreviewFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "subscribe enqueues mail and redirects to thanks" do
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post free_preview_path, params: { free_preview_request: { email: "NEW@Example.com " } }
    end
    assert_redirected_to free_preview_thanks_path
  end

  test "invalid email returns errors" do
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      post free_preview_path, params: { free_preview_request: { email: "not-an-email" } }
    end
    assert_response :unprocessable_entity
  end

  test "valid preview token redirects to first chapter" do
    token = DemoPreviewLink.generate!("reader@example.com")
    get books_preview_access_url(t: token)
    assert_redirected_to books_coffeeshop_chapter_path(1)
  end

  test "invalid preview token redirects to request form" do
    get books_preview_access_url(t: "invalid")
    assert_redirected_to new_free_preview_path
  end
end
