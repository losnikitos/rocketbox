# frozen_string_literal: true

module Accounts
  class PromptsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_prompt, only: %i[edit update destroy]

    def index
      @prompts = Prompt.with_attached_examples.ordered
      @prompts = @prompts.joins(:tag).where(tag: { slug: params[:tag] }) if params[:tag].present?
    end

    def new
      @prompt = Prompt.new(draft_params)
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
      @prompt.assign_attributes(draft_params)
      @prompt.fill_options
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
        params.expect(prompt: [ :name, :tag_id, :kind, :body, examples: [], options: {} ])
      end

      # The options refresh resubmits the form as a GET; examples wait for the save.
      def draft_params = params[:prompt] ? prompt_params.except(:examples) : {}
  end
end
