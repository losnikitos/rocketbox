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

    def new
      @recipes = Recipe.ordered
      @selected_media = selected_library_media
      if @selected_media.empty?
        redirect_to library_uploads_path, alert: "Select at least one image from your library."
        return
      end
      if @recipes.empty?
        redirect_to library_uploads_path, alert: "No recipes are available yet. Ask an admin to add recipes."
        return
      end

      @post = Current.account.smm_posts.new
    end

    def create
      @recipes = Recipe.ordered
      @selected_media = selected_library_media
      recipe = Recipe.find_by(id: params[:recipe_id])

      if @selected_media.empty?
        redirect_to library_uploads_path, alert: "Select at least one image from your library."
        return
      end

      unless recipe
        flash.now[:alert] = "Choose a recipe."
        @post = Current.account.smm_posts.new(caption: params[:caption])
        render :new, status: :unprocessable_entity
        return
      end

      @post = Current.account.smm_posts.new(
        recipe:,
        format: recipe.format,
        caption: params[:caption].to_s.strip.presence,
        status: "draft"
      )
      @selected_media.each_with_index do |media, index|
        @post.smm_post_media_items.build(library_media: media, position: index)
      end

      if @post.save
        WorkflowRun.start!(@post)
        redirect_to instagram_post_path(@post), notice: "Draft post created. Generating…"
      else
        flash.now[:alert] = @post.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @post = Current.account.smm_posts.includes(:recipe, :library_media, smm_slides: { media_attachment: :blob },
        workflow_run: { workflow_steps: { outputs_attachments: :blob } }).find(params[:id])
    end

    def pause
      workflow_run.pause!
      redirect_to instagram_post_path(workflow_run.subject), notice: "Paused after the current step."
    end

    def resume
      workflow_run.resume!
      redirect_to instagram_post_path(workflow_run.subject), notice: "Resumed."
    end

    # Retry a failed step, or re-run any step and everything after it.
    def rerun
      step = workflow_run.workflow_class[params.expect(:key)] or return head(:unprocessable_entity)

      workflow_run.rerun!(step.key)
      redirect_to instagram_post_path(workflow_run.subject), notice: "Running again from #{step.key.humanize}."
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

    private

      def workflow_run
        @workflow_run ||= Current.account.smm_posts.find(params[:id]).workflow_run || raise(ActiveRecord::RecordNotFound)
      end

      def selected_library_media
        ids = Array(params[:library_media_ids]).map(&:presence).compact.map(&:to_i).uniq
        return [] if ids.empty?

        media_by_id = Current.account.library_media.with_attached_file.where(id: ids).index_by(&:id)
        ids.filter_map { |id| media_by_id[id] }
      end
  end
end
