# frozen_string_literal: true

module Accounts
  class GuideChaptersController < ApplicationController
    layout "app"

    before_action :authenticate_admin!

    def show
      @guide = Guide.friendly.find(params[:studio_guide_slug])
      @chapter = @guide.chapters.friendly.find(params[:slug])
    end
  end
end
