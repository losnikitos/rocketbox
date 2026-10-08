# frozen_string_literal: true

module Accounts
  # Adds a blank run to a workflow, or deletes one none of whose step runs is still running; the media its step runs
  # made stay in the library.
  class WorkflowRunsController < ApplicationController
    before_action :authenticate_admin!
    before_action :set_workflow

    def create
      redirect_to workflow_path(@workflow, run: @workflow.runs.create!.id)
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
