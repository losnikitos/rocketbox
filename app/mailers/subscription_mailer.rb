# frozen_string_literal: true

class SubscriptionMailer < ApplicationMailer
  include PostmarkRails::TemplatedMailerMixin

  def subscribe_magic_link
    self.template_model = {
      subscribe_url: params[:subscribe_url],
      expiration_phrase: ActionController::Base.helpers.pluralize(
        SubscriptionLink::EXPIRATION_DAYS,
        "day"
      )
    }

    mail to: params[:email], postmark_template_alias: "subscribe_magic_link"
  end
end
