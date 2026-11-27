# frozen_string_literal: true

class GuidesController < ApplicationController
  def index
    @guides = Guide.published.order(:title)
  end

  def show
    @guide = Guide.published.friendly.find(params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to guides_path, alert: "That guide could not be found."
  end
end
