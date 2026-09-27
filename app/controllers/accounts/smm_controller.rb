# frozen_string_literal: true

module Accounts
  class SmmController < ApplicationController
    layout "app"

    def index
      @posts = Current.account.smm_posts.includes({ library_media: { file_attachment: :blob } }, generated_video_attachment: :blob).recent
    end

    def reels
    end

    def stories
    end
  end
end
