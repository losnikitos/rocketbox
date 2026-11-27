# frozen_string_literal: true

module Accounts
  class StoryboardsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_storyboard, except: :index
    before_action :set_scene, only: %i[show canvas]

    def index
      @storyboards = Storyboard::ALL
    end

    def show
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

    private

      def set_storyboard
        @storyboard = Storyboard.find(params[:id])
      end

      def set_scene
        @scene = params[:scene].present? ? @storyboard.find_scene(params[:scene]) : @storyboard.scenes.first
      end
  end
end
