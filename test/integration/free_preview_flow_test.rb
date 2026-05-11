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
    book = Book.find_or_create_by!(slug: "coffeeshop") do |b|
      b.title = "Coffee Shop"
    end
    first_chapter = book.chapters.order(:position).first || book.chapters.create!(
      title: "Why this guide exists",
      position: 1,
      free: true,
    )

    token = DemoPreviewLink.generate!("reader@example.com")
    get books_preview_access_url(t: token)
    assert_redirected_to books_book_chapter_path("coffeeshop", first_chapter)
  end

  test "invalid preview token redirects to request form" do
    get books_preview_access_url(t: "invalid")
    assert_redirected_to new_free_preview_path
  end
end
