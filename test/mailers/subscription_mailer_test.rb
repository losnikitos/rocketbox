# frozen_string_literal: true

require "test_helper"

class SubscriptionMailerTest < ActionMailer::TestCase
  test "subscribe_magic_link sends link to inbox" do
    subscribe_url = "https://example.com/subscription/access?t=abc"
    mail = SubscriptionMailer.with(email: "reader@example.com", subscribe_url:).subscribe_magic_link

    assert_equal [ "reader@example.com" ], mail.to
    assert_equal "subscribe_magic_link", mail.template_alias

    model = mail.template_model
    assert_equal subscribe_url, model[:subscribe_url]
    assert_equal(
      ActionController::Base.helpers.pluralize(SubscriptionLink::EXPIRATION_DAYS, "day"),
      model[:expiration_phrase]
    )
  end
end
