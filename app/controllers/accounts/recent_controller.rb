# frozen_string_literal: true

module Accounts
  class RecentController < ApplicationController
    layout -> { turbo_frame_request? ? false : "app" }

    PER_PAGE = 20

    def show
      @library_media = Current.account.library_media.with_attached_file.includes(:transformation_run)
        .order(id: :desc).limit(PER_PAGE)
      @library_media = @library_media.where(id: ...params[:before].to_i) if params[:before].present?
    end
  end
end
