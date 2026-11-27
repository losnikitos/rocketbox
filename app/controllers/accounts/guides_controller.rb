# frozen_string_literal: true

module Accounts
  # Studio read-only browse of guides (incl. unpublished). Public site is GuidesController.
  class GuidesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!

    def index
      @guides = Guide.order(:title).includes(:chapters)
    end

    def show
      @guide = Guide.includes(chapters: :rules).friendly.find(params[:slug])
    end
  end
end
