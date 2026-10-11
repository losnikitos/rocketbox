# frozen_string_literal: true

module Accounts
  # Prompts are browsed in their library folders (see FoldersController); these add, edit and remove one.
  class PromptsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_prompt, only: %i[edit update destroy]

    def new
      @prompt = Prompt.new(folder: Folder.prompt.find_by(id: params[:folder_id]) || Folder.ready("prompt"))
    end

    def create
      @prompt = Prompt.new(prompt_params)
      if @prompt.save
        redirect_to helpers.folder_path(@prompt.folder), notice: "Prompt added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @prompt.update(prompt_params)
        redirect_to helpers.folder_path(@prompt.folder), notice: "Prompt saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @prompt.destroy!
      redirect_to helpers.folder_path(@prompt.folder), notice: "Prompt removed."
    end

    private

      # Shared prompts, or the account's (written by its step runs).
      def set_prompt
        @prompt = Prompt.where(user_id: [ nil, Current.account.id ]).find(params[:id])
      end

      def prompt_params
        params.expect(prompt: [ :name, :folder_id, :body, examples: [] ])
      end
  end
end
