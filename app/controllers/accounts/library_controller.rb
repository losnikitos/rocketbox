# frozen_string_literal: true

module Accounts
  class LibraryController < ApplicationController
    layout "app"

    def show
      @media = Current.account.library_media.with_attached_file.includes(
        :folder, :tags, transformation_run: [ :transformation, :shot, { workflow_run: :workflow, workflow_node: :transformation }, { inputs: { library_media: { file_attachment: :blob } } } ]
      ).find(params[:id])
      @versions = @media.original.lineage
      # ponytail: loads every sibling; add a window around @media if libraries get big
      @siblings = if @media.ready? && (step_id = @media.transformation_run&.workflow_node_id)
        Current.account.library_media.where(folder: Folder.ready).joins(:transformation_run).where(transformation_runs: { workflow_node_id: step_id })
      else
        Current.account.library_media.where(folder: @media.folder)
      end
      @siblings = @siblings.with_attached_file.includes(:transformation_run).order(created_at: :desc)
    end
  end
end
