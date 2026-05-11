# frozen_string_literal: true

class DemoPreviewMailerPreview < ActionMailer::Preview
  def demo_chapter
    preview_url = Rails.application.routes.url_helpers.books_preview_access_url(
      t: "preview-token",
      **Rails.application.config.action_mailer.default_url_options
    )
    DemoPreviewMailer.with(email: "preview@example.com", preview_url:).demo_chapter
  end
end
