# frozen_string_literal: true

require "test_helper"

class DemoPreviewMailerTest < ActionMailer::TestCase
  test "demo_chapter sends link to inbox" do
    preview_url = "https://example.com/books/preview?t=abc"
    mail = DemoPreviewMailer.with(email: "reader@example.com", preview_url:).demo_chapter

    assert_equal [ "reader@example.com" ], mail.to
    assert_equal "demo_chapter", mail.template_alias

    model = mail.template_model
    assert_equal preview_url, model[:preview_url]
    assert_equal(
      ActionController::Base.helpers.pluralize(DemoPreviewLink::EXPIRATION_DAYS, "day"),
      model[:expiration_phrase]
    )
  end
end
