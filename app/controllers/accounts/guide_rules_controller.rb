# frozen_string_literal: true

module Accounts
  class GuideRulesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!

    def show
      @guide = Guide.friendly.find(params[:studio_guide_slug])
      @chapter = @guide.chapters.friendly.find(params[:chapter_slug])
      @rule = @chapter.rules.find_by!(number: params[:number])
    end
  end
end
