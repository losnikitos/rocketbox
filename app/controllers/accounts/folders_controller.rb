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
      media = Current.account.library_media.with_attached_file.includes(:transformation_run).order(created_at: :desc)
      if @folder
        @folder_media = media.where(folder: @folder.children).group_by(&:folder_id)
        @library_media = Current.account.library_media.where(folder: @folder).with_attached_file
          .includes(:tags, transformation_run: { inputs: { library_media: { file_attachment: :blob } } }, generated_media: { file_attachment: :blob })
          .order(created_at: :desc)
        # One end of an edge is always a step, so a folder node an edge leaves is an input, one it enters an output.
        nodes = WorkflowNode.includes(:workflow, :folder).where(folder: @folder)
        @read_nodes = nodes.where(id: WorkflowEdge.select(:from_id)).to_a
        @write_nodes = nodes.where(id: WorkflowEdge.select(:to_id)).to_a
        # A step with no output folder lands its results in Ready.
        if @folder == Folder.ready
          @write_nodes += WorkflowNode.includes(:workflow, :transformation).where.not(transformation_id: nil)
            .where.not(id: WorkflowEdge.joins(:to).where(workflow_nodes: { transformation_id: nil }).select(:from_id)).to_a
        end
      else
        @folder_media = media.includes(:folder).group_by { it.folder.parent_id || it.folder_id }
      end
    end

    def create
      parent = Folder.roots.find_by!(slug: params[:root]) if params[:root]
      folder = Folder.new(parent:, name: params.dig(:folder, :name))
      if folder.save
        redirect_to helpers.folder_path(folder), notice: "Folder created."
      else
        redirect_to parent_path(parent), alert: folder.errors.full_messages.to_sentence
      end
    end

    def update
      if @folder.update(params.expect(folder: %i[name color]))
        redirect_to helpers.folder_path(@folder), notice: "Folder updated."
      else
        redirect_to helpers.folder_path(@folder), alert: @folder.errors.full_messages.to_sentence
      end
    end

    def destroy
      parent = @folder.parent
      if @folder.destroy_into_parent
        redirect_to parent_path(parent), notice: [ "Folder deleted.", ("Its media moved to #{parent.name}." if parent) ].compact.join(" ")
      else
        redirect_to helpers.folder_path(@folder), alert: @folder.errors.full_messages.to_sentence.presence || "Folder can't be deleted."
      end
    end

    private

      def parent_path(parent) = parent ? helpers.folder_path(parent) : library_folders_path

      def set_folder
        return unless params[:root]

        @folder = Folder.roots.find_by!(slug: params[:root])
        @folder = @folder.children.find_by!(slug: params[:child]) if params[:child]
      end
  end
end
