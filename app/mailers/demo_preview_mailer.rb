# frozen_string_literal: true

class DemoPreviewMailer < ApplicationMailer
  include PostmarkRails::TemplatedMailerMixin

  def demo_chapter
    self.template_model = {
      preview_url: params[:preview_url],
      expiration_phrase: ActionController::Base.helpers.pluralize(
        DemoPreviewLink::EXPIRATION_DAYS,
        "day"
      )
    }

    mail to: params[:email], postmark_template_alias: "demo_chapter"
  end
end
