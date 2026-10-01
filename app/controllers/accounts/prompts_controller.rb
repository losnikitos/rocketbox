# frozen_string_literal: true

module Accounts
  class PromptsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_prompt, only: %i[edit update destroy]

    def index
      @prompts = Prompt.with_attached_examples.ordered
      @prompts = @prompts.joins(:media_type).where(media_type: { slug: params[:media_type] }) if params[:media_type].present?
    end

    def new
      @prompt = Prompt.new
    end

    def create
      @prompt = Prompt.new(prompt_params)
      if @prompt.save
        redirect_to prompts_path, notice: "Prompt added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @prompt.update(prompt_params)
        redirect_to prompts_path, notice: "Prompt saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @prompt.destroy!
      redirect_to prompts_path, notice: "Prompt removed."
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to prompts_path, alert: "This prompt has generations and can't be removed."
    end

    private

      def set_prompt
        @prompt = Prompt.find(params[:id])
      end

      def prompt_params
        params.expect(prompt: [ :name, :media_type_id, :kind, :body, examples: [] ])
      end
  end
end
