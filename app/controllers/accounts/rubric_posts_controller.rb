# frozen_string_literal: true

module Accounts
  class RubricPostsController < ApplicationController
    layout "app"

    before_action :set_post

    def show
    end

    def publish
      if @post.published_at
        redirect_to rubric_post_path(@rubric, @post), alert: "Already published."
      else
        @post.update!(scheduled_at: Time.current, error_message: nil)
        PublishRubricPostJob.perform_later(@post)
        redirect_to rubric_post_path(@rubric, @post), notice: "Publishing…"
      end
    end

    private

      def set_post
        @rubric = Current.account.rubrics.find(params[:rubric_id])
        @post = @rubric.posts.find(params[:id])
      end
  end
end
