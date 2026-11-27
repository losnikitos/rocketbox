# frozen_string_literal: true

module Accounts
  class PostsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_post, only: %i[show edit update destroy canvas render_video]
    before_action :set_scene, only: %i[show canvas]

    def index
      Post.ensure_defaults!
      @posts = Post.order(created_at: :desc)
    end

    def show
      @renders = @post.renders.order(created_at: :desc)
      respond_to do |format|
        format.html
        format.png do
          return head :bad_request unless @scene.renderable?

          html = render_to_string(:canvas, layout: false, formats: :html, locals: { data_url: true })
          send_data Storyboard.screenshot(html, size: @storyboard.size),
            type: "image/png", disposition: "attachment",
            filename: "post-#{@post.id}-#{@scene.slug}.png"
        end
      end
    end

    def new
      board = Storyboard.find(params[:storyboard].presence || Storyboard::GUIDE_PROMO.slug)
      @post = Post.new(board.default_post_attrs.merge(name: "#{board.name} copy", source: "", rules: board.rule_numbers))
      @storyboard = board
    end

    def create
      @post = Post.new(post_params)
      @post.rules = normalize_rules(@post.rules)
      @storyboard = @post.storyboard rescue Storyboard::GUIDE_PROMO
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
        redirect_to post_path(@post, scene: params[:scene].presence)
      else
        @renders = @post.renders.order(created_at: :desc)
        @scene = @post.scenes.first
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
      redirect_to post_path(@post, scene: params[:scene].presence), notice: "Rendering…"
    end

    private

      def set_post
        @post = Post.find(params[:id])
        @storyboard = @post.storyboard
      end

      def set_scene
        @scene = if params[:scene].present?
          @post.find_scene(params[:scene])
        else
          @post.scenes.first
        end
      end

      def post_params
        params.require(:post).permit(:name, :storyboard_slug, :source, rules: [])
      end

      def normalize_rules(raw)
        Array(raw).map(&:to_i).uniq.select { it.positive? }
      end
  end
end
