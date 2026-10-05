# frozen_string_literal: true

module Accounts
  class PostsController < ApplicationController
    layout "app"

    FORMATS_BY_KIND = { "reels" => "reel", "stories" => "story", "posts" => "post" }.freeze
    KINDS = FORMATS_BY_KIND.keys.freeze

    def index
      @kind = params[:kind].presence_in(KINDS)
      @posts = Current.account.smm_posts.includes({ library_media: { file_attachment: :blob } }, smm_slides: { media_attachment: :blob }).recent
      @posts = @posts.where(format: FORMATS_BY_KIND[@kind]) if @kind
    end

    def show
      @post = Current.account.smm_posts.includes({ library_media: [ { folder: :parent }, { file_attachment: :blob } ] }, smm_slides: { media_attachment: :blob }).find(params[:id])
    end

    def publish
      @post = Current.account.smm_posts.find(params[:id])
      unless @post.publishable?
        redirect_to instagram_post_path(@post), alert: "This post is not ready to publish yet."
        return
      end

      @post.update!(error_message: nil)
      PublishSmmPostJob.perform_later(@post.id)
      redirect_to instagram_post_path(@post), notice: "Publishing to Instagram…"
    end

    def destroy
      unless Current.user.admin?
        redirect_to instagram_posts_path, alert: "You are not allowed to remove posts."
        return
      end

      Current.account.smm_posts.find(params[:id]).destroy!
      redirect_to instagram_posts_path, notice: "Post removed."
    end

    def react
      @post = Current.account.smm_posts.find(params[:id])
      reaction = params[:reaction].to_s.presence
      unless reaction.nil? || SmmPost::REACTIONS.include?(reaction)
        return render json: { error: "Invalid reaction" }, status: :unprocessable_entity
      end

      attrs = { reaction: }
      if reaction != "down"
        attrs[:reaction_comment] = nil
      elsif params.key?(:reaction_comment)
        attrs[:reaction_comment] = params[:reaction_comment].to_s.strip.presence
      end

      @post.update!(attrs)
      render json: { reaction: @post.reaction, reaction_comment: @post.reaction_comment }
    end
  end
end
