# frozen_string_literal: true

require "test_helper"

class DemoPreviewMailerTest < ActionMailer::TestCase
  test "demo_chapter sends link to inbox" do
    preview_url = "https://example.com/books/preview?t=abc"
    mail = DemoPreviewMailer.with(email: "reader@example.com", preview_url:).demo_chapter

    assert_equal "Your free Rocketbox preview", mail.subject
    assert_equal ["reader@example.com"], mail.to
    assert_includes mail.html_part.decoded, preview_url
    assert_includes mail.text_part.decoded, preview_url
  end
end
