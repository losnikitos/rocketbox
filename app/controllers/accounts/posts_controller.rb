# frozen_string_literal: true

module Accounts
  class PostsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    # Post Markdown is public for coding agents (see docs/POST_FRAMES.md).
    skip_before_action :authenticate, :authenticate_admin!, :require_account_param, if: :markdown?
    before_action :set_post, only: %i[show edit update destroy canvas render_video]
    before_action :set_scene, only: %i[canvas]

    def index
      Post.ensure_defaults!
      @posts = Post.includes(frames: { file_attachment: :blob }).order(created_at: :desc)
    end

    def show
      respond_to do |format|
        format.html { @renders = @post.renders.order(created_at: :desc) }
        format.md do
          @guide = @preset.try(:guide)
          @rules = @guide ? @guide.rules.where(number: @post.rules_list).index_by(&:number) : {}
          @source = @post.source_media
        end
      end
    end

    def new
      preset = Preset.find(params[:preset].presence || Preset::GuidePromo::SLUG)
      @post = Post.new(preset.default_post_attrs)
      @preset = preset
    end

    def create
      @post = Post.new(post_params)
      @post.rules = normalize_rules(@post.rules)
      @preset = @post.preset rescue Preset::GuidePromo.new
      if @post.save
        redirect_to post_path(@post)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to post_path(@post)
    end

    def update
      attrs = post_params
      attrs[:rules] = normalize_rules(attrs[:rules])
      if @post.update(attrs)
        redirect_to post_path(@post)
      else
        @renders = @post.renders.order(created_at: :desc)
        flash.now[:alert] = @post.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      @post.destroy!
      redirect_to posts_path, notice: "Post deleted."
    end

    def canvas
      render layout: false, locals: { data_url: false }
    end

    def render_video
      source = @post.source.to_s.strip
      return redirect_to(post_path(@post), alert: "Set a source image before rendering.") if source.blank?

      render_row = @post.renders.create!(status: :pending)
      PostRenderJob.perform_later(render_row)
      redirect_to post_path(@post), notice: "Rendering…"
    end

    private

      def set_post
        @post = Post.find(params[:id])
        @preset = @post.preset
      end

      def set_scene
        @scene = if params[:scene].present?
          @post.find_scene(params[:scene])
        else
          @post.scenes.first
        end
      end

      # The action is checked here: `only:` beside `if:` on a skip would skip for every show.
      def markdown?
        action_name == "show" && request.format.md?
      end

      def post_params
        params.require(:post).permit(:preset_slug, :source, :transition_type, rules: [])
      end

      def normalize_rules(raw)
        Array(raw).map(&:to_i).uniq.select { it.positive? }
      end
  end
end
