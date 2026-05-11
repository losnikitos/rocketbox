# frozen_string_literal: true

class SubscriptionMailerPreview < ActionMailer::Preview
  def subscribe_magic_link
    subscribe_url = Rails.application.routes.url_helpers.subscription_access_url(
      t: "subscription-token",
      **Rails.application.config.action_mailer.default_url_options
    )

    SubscriptionMailer.with(email: "preview@example.com", subscribe_url:).subscribe_magic_link
  end
end
