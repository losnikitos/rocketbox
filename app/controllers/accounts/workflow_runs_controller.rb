# frozen_string_literal: true

module Accounts
  # Adds a blank run to a workflow, or, given a start folder `node_id` and a `media_id` it takes (a media page's Run in
  # workflow), plays a new run of that media alone from it. Picks a start folder's media for a draft one (none picked goes
  # back to its newest N), or deletes one none of whose step runs is still running; the media its step runs made stay in the library.
  class WorkflowRunsController < ApplicationController
    before_action :authenticate_admin!
    before_action :set_workflow

    def create
      return redirect_to(workflow_path(@workflow, run: @workflow.runs.create!.id)) unless params[:media_id]

      media = Current.account.library_media.find(params[:media_id])
      node = @workflow.start_nodes.find { it.id == params[:node_id].to_i && it.takes?(media) }
      return redirect_back_or_to(library_item_path(media), alert: "This workflow doesn't start from #{media.folder.path}.") unless node

      redirect_to workflow_path(@workflow, run: @workflow.start_with!(node, media, Current.account).id, node: node.id)
    end

    def update
      run = @workflow.runs.find(params[:id])
      node = @workflow.nodes.find(params[:node_id])
      unless run.draft?
        return redirect_to(workflow_path(@workflow, run: run.id, node: node.id), alert: "This run has started, so its picks are locked. Add a new run to pick other media.")
      end

      ids = Array(params[:media_ids]).compact_blank.map(&:to_i)
      run.update!(picks: ids.any? ? run.picks.merge(node.id.to_s => ids) : run.picks.except(node.id.to_s))
      redirect_to workflow_path(@workflow, run: run.id, node: node.id)
    end

    def destroy
      run = @workflow.runs.find(params[:id])
      return redirect_to(workflow_path(@workflow, run: run.id), alert: "Wait for its steps to finish before deleting this run.") if run.running?

      run.destroy!
      redirect_to workflow_path(@workflow, run: @workflow.runs.last&.id), notice: "Run deleted."
    end

    private

      def set_workflow
        @workflow = Workflow.find(params[:workflow_id])
      end
  end
end
