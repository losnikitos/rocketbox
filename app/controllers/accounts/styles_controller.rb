# frozen_string_literal: true

module Accounts
  class StylesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_style, only: %i[edit update destroy]

    def index
      @styles = Style.with_attached_examples.ordered
    end

    def new
      @style = Style.new
    end

    def create
      @style = Style.new(style_params)
      if @style.save
        redirect_to styles_path, notice: "Style added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @style.update(style_params)
        redirect_to styles_path, notice: "Style saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @style.destroy!
      redirect_to styles_path, notice: "Style removed."
    end

    private

      def set_style
        @style = Style.find(params[:id])
      end

      def style_params
        params.expect(style: [ :name, :body, examples: [] ])
      end
  end
end
