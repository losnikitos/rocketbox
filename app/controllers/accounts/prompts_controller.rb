# frozen_string_literal: true

module Accounts
  class PromptsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_prompt, only: %i[edit update destroy]

    def index
      @prompts = Prompt.with_attached_examples.ordered
      @prompts = @prompts.where(folder: params[:folder]) if params[:folder].present?
    end

    def new
      @prompt = Prompt.new(params.permit(:folder).compact_blank)
    end

    def create
      @prompt = Prompt.new(prompt_params)
      if @prompt.save
        redirect_to prompts_path(folder: @prompt.folder), notice: "Prompt added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @prompt.update(prompt_params)
        redirect_to prompts_path(folder: @prompt.folder), notice: "Prompt saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @prompt.destroy!
      redirect_to prompts_path(folder: @prompt.folder), notice: "Prompt removed."
    end

    private

      def set_prompt
        @prompt = Prompt.find(params[:id])
      end

      def prompt_params
        params.expect(prompt: [ :name, :folder, :body, examples: [] ])
      end
  end
end
