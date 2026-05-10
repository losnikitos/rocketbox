# frozen_string_literal: true

class FreePreviewsController < ApplicationController
  skip_before_action :authenticate, only: %i[new create thanks]

  def new
    @request = FreePreviewRequest.new
  end

  def create
    @request = FreePreviewRequest.new(free_preview_params)

    if @request.valid?
      token = DemoPreviewLink.generate!(@request.email)
      preview_url = books_preview_access_url(t: token)
      DemoPreviewMailer.with(email: @request.email, preview_url:).demo_chapter.deliver_later
      redirect_to free_preview_thanks_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def thanks
  end

  private

    def free_preview_params
      params.expect(free_preview_request: [:email])
    end
end
