# frozen_string_literal: true

class GuideChaptersController < ApplicationController
  def show
    @guide = Guide.published.friendly.find(params[:guide_slug])
    @chapter = @guide.chapters.friendly.find(params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to guides_path, alert: "That chapter could not be found."
  end
end
