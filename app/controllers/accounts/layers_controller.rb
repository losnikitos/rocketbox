# frozen_string_literal: true

module Accounts
  class LayersController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_layer, except: :index

    def index
      @layers = Layer::ALL
    end

    def show
      respond_to do |format|
        format.html
        format.png do
          html = render_to_string(:canvas, layout: false, formats: :html)
          send_data Layer.screenshot(html, size: @layer.size), type: "image/png", disposition: "attachment", filename: "#{@layer.slug}.png"
        end
      end
    end

    def canvas
      render layout: false
    end

    private

      def set_layer
        @layer = Layer.find(params[:id])
        @values = @layer.values(params)
      end
  end
end
