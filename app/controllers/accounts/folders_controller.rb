# frozen_string_literal: true

module Accounts
  class FoldersController < ApplicationController
    layout "app"

    # Folders are global, so only admins change them.
    before_action :authenticate_admin!, except: :show
    before_action :set_folder, except: :create

    # ponytail: @folder_media loads every media in the listed folders just to count them and preview the newest few.
    # Upgrade = a COUNT query plus a per-folder LIMIT (window function) once accounts hold thousands of media.
    def show
      @folder_counts = Current.account.library_media.group(:folder_id).count
      media = Current.account.library_media.with_attached_file.includes(:recipe_run).order(created_at: :desc)
      if @folder
        @folder_media = media.where(folder: @folder.children).group_by(&:folder_id)
        @library_media = Current.account.library_media.where(folder: @folder).with_attached_file
          .includes(recipe_run: { inputs: { library_media: { file_attachment: :blob } } }).order(created_at: :desc)
        @library_media = @library_media.joins(:recipe_run).where(recipe_runs: { recipe_id: params[:recipe] }) if params[:recipe].present?
        @recipes = Recipe.with_attached_examples.includes(:output_folder).ordered.select { it.folder_ids.include?(@folder.id) }
      else
        @folder_media = media.includes(:folder).group_by { it.folder.parent_id || it.folder_id }
      end
    end

    def create
      parent = Folder.roots.find_by!(slug: params[:root])
      folder = parent.children.new(name: params.dig(:folder, :name))
      if folder.save
        redirect_to helpers.folder_path(folder), notice: "Folder created."
      else
        redirect_to helpers.folder_path(parent), alert: folder.errors.full_messages.to_sentence
      end
    end

    def update
      if @folder.update(name: params.dig(:folder, :name))
        redirect_to helpers.folder_path(@folder), notice: "Folder renamed."
      else
        redirect_to helpers.folder_path(@folder), alert: @folder.errors.full_messages.to_sentence
      end
    end

    def destroy
      parent = @folder.parent
      if @folder.destroy_into_parent
        redirect_to helpers.folder_path(parent), notice: "Folder deleted. Its media moved to #{parent.name}."
      else
        redirect_to helpers.folder_path(@folder), alert: @folder.errors.full_messages.to_sentence.presence || "Folder can't be deleted."
      end
    end

    private

      def set_folder
        return unless params[:root]

        @folder = Folder.roots.find_by!(slug: params[:root])
        @folder = @folder.children.find_by!(slug: params[:child]) if params[:child]
      end
  end
end
