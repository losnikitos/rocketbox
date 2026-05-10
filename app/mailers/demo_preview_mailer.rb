# frozen_string_literal: true

class DemoPreviewMailer < ApplicationMailer
  def demo_chapter
    @preview_url = params[:preview_url]

    mail to: params[:email], subject: "Your free Rocketbox preview"
  end
end
