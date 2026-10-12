# frozen_string_literal: true

module Accounts
  class RubricPostsController < ApplicationController
    layout "app"

    before_action :set_rubric
    before_action :set_post, only: %i[show publish destroy]

    def show
    end

    # Saves the calendar's planned post at scheduled_at, so its media is kept for it and it goes out then.
    def create
      time = (Time.iso8601(params[:scheduled_at].to_s).in_time_zone rescue nil)
      _, _, media = Rubric.plan(Current.account.rubrics.to_a, time + 1.second).find { |t, rubric| rubric == @rubric && t == time } if time
      if media
        redirect_to rubric_post_path(@rubric, @rubric.posts.create!(scheduled_at: time, library_media: media))
      else
        redirect_back_or_to edit_rubric_path(@rubric), alert: "Nothing is planned to post then."
      end
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

    def destroy
      @post.destroy!
      redirect_to edit_rubric_path(@rubric), notice: "Post deleted."
    end

    private

      def set_rubric
        @rubric = Current.account.rubrics.find(params[:rubric_id])
      end

      def set_post
        @post = @rubric.posts.find(params[:id])
      end
  end
end
