# frozen_string_literal: true

module Accounts
  class PostsController < ApplicationController
    layout "app"

    def index
      @posts = Current.account.smm_posts.includes(:prompt, { library_media: { file_attachment: :blob } }, generated_video_attachment: :blob).recent
    end

    def new
      @prompts = Prompt.library
      @selected_media = selected_library_media
      if @selected_media.empty?
        redirect_to library_uploads_path, alert: "Select at least one image from your library."
        return
      end
      if @prompts.empty?
        redirect_to library_uploads_path, alert: "No prompts are available yet. Ask an admin to add prompts."
        return
      end

      @post = Current.account.smm_posts.new
    end

    def create
      @prompts = Prompt.library
      @selected_media = selected_library_media
      prompt = Prompt.library.find_by(id: params[:prompt_id])

      if @selected_media.empty?
        redirect_to library_uploads_path, alert: "Select at least one image from your library."
        return
      end

      unless prompt
        flash.now[:alert] = "Choose a prompt from the library."
        @post = Current.account.smm_posts.new(caption: params[:caption])
        render :new, status: :unprocessable_entity
        return
      end

      @post = Current.account.smm_posts.new(
        prompt:,
        caption: params[:caption].to_s.strip.presence,
        status: "draft"
      )
      @selected_media.each_with_index do |media, index|
        @post.smm_post_media_items.build(library_media: media, position: index)
      end

      if @post.save
        GenerateSmmPostVideoJob.perform_later(@post.id)
        redirect_to smm_post_path(@post), notice: "Draft post created. Generating your Instagram video…"
      else
        flash.now[:alert] = @post.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @post = Current.account.smm_posts.includes(:prompt, :library_media, generated_video_attachment: :blob).find(params[:id])
    end

    def publish
      @post = Current.account.smm_posts.find(params[:id])
      unless @post.publishable?
        redirect_to smm_post_path(@post), alert: "This post is not ready to publish yet."
        return
      end

      @post.update!(error_message: nil)
      PublishSmmPostJob.perform_later(@post.id)
      redirect_to smm_post_path(@post), notice: "Publishing to Instagram…"
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

    private

      def selected_library_media
        ids = Array(params[:library_media_ids]).map(&:presence).compact.map(&:to_i).uniq
        return [] if ids.empty?

        media_by_id = Current.account.library_media.with_attached_file.where(id: ids).index_by(&:id)
        ids.filter_map { |id| media_by_id[id] }
      end
  end
end
