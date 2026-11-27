# frozen_string_literal: true

module Accounts
  class StoryboardsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_storyboard, except: :index
    before_action :set_settings, except: :index
    before_action :set_scene, only: %i[show canvas]

    def index
      @storyboards = Storyboard::ALL
    end

    def show
      @renders = StoryboardRender.where(storyboard_slug: @storyboard.slug).order(created_at: :desc)
      respond_to do |format|
        format.html
        format.png do
          return head :bad_request unless @scene.renderable?

          html = render_to_string(:canvas, layout: false, formats: :html, locals: { data_url: true })
          send_data Storyboard.screenshot(html, size: @storyboard.size),
            type: "image/png", disposition: "attachment",
            filename: "#{@storyboard.slug}-#{@scene.slug}.png"
        end
      end
    end

    def canvas
      render layout: false, locals: { data_url: false }
    end

    def update_settings
      attrs = settings_params
      attrs[:videos] = normalize_videos(attrs[:videos])
      attrs[:overlays] = normalize_overlays(attrs[:overlays])
      if params[:add_video].present?
        attrs[:videos] << { "source" => "", "rules" => attrs[:overlays].map { it["number"] } }
      end
      if params[:remove_video].present?
        attrs[:videos].delete_at(params[:remove_video].to_i)
      end
      if attrs[:videos].empty?
        @settings.errors.add(:videos, "add at least one video")
        return render_settings_error
      end

      # Blank source allowed while drafting a new row; render_video requires one.
      @settings.update_columns(
        transition_type: attrs[:transition_type],
        cta_text: attrs[:cta_text],
        cta_href: attrs[:cta_href],
        overlays: attrs[:overlays],
        videos: attrs[:videos],
        updated_at: Time.current
      )

      redirect_to storyboard_path(@storyboard, scene: params[:scene].presence, video: params[:video].presence)
    end

    def render_video
      index = params[:video].to_i
      raise ActiveRecord::RecordNotFound if @settings.videos[index].blank?

      source = @settings.videos[index]["source"].to_s.strip
      return redirect_to(storyboard_path(@storyboard, video: index), alert: "Set a source image for video #{index + 1}.") if source.blank?

      render_row = StoryboardRender.create!(storyboard_slug: @storyboard.slug, video_index: index, status: :pending)
      StoryboardRenderJob.perform_later(render_row)
      redirect_to storyboard_path(@storyboard, scene: params[:scene].presence, video: index),
        notice: "Rendering video #{index + 1}…"
    end

    private

      def set_storyboard
        @storyboard = Storyboard.find(params[:id])
      end

      def set_settings
        @settings = @storyboard.settings
        @settings.save! if @settings.new_record?
        @video_index = params[:video].presence&.to_i || 0
        @video_index = 0 if @settings.videos[@video_index].blank?
      end

      def set_scene
        @scene = if params[:scene].present?
          @storyboard.find_scene(params[:scene], video_index: @video_index)
        else
          @storyboard.scenes(video_index: @video_index).first
        end
      end

      def settings_params
        {
          transition_type: params.fetch(:transition_type, "simple_fade"),
          cta_text: params[:cta_text].to_s,
          cta_href: params[:cta_href].to_s,
          overlays: params[:overlays].presence || [],
          videos: params[:videos].presence || []
        }
      end

      def normalize_overlays(raw)
        rows = raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash) ? raw.values : Array(raw)
        rows.filter_map do |row|
          row = row.permit(:number, :text).to_h if row.respond_to?(:permit)
          number = row["number"].presence || row[:number]
          next if number.blank?

          { "number" => number.to_i, "text" => (row["text"] || row[:text]).to_s }
        end
      end

      def normalize_videos(raw)
        list = raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash) ? raw.values : Array(raw)
        list.map do |row|
          row = row.permit(:source, rules: [], afters: []).to_h if row.respond_to?(:permit)
          rules = Array(row["rules"] || row[:rules]).map(&:to_i).uniq
          afters = Array(row["afters"] || row[:afters]).flatten.compact_blank
          {
            "source" => (row["source"] || row[:source]).to_s.strip,
            "rules" => rules,
            **(afters.present? ? { "afters" => afters } : {})
          }
        end
      end

      def render_settings_error
        @renders = StoryboardRender.where(storyboard_slug: @storyboard.slug).order(created_at: :desc)
        @scene = @storyboard.scenes(video_index: @video_index).first
        flash.now[:alert] = @settings.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity
      end
  end
end
