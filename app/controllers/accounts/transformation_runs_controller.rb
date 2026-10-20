# frozen_string_literal: true

module Accounts
  # Approve or reject a waiting Approval step run from the workflow canvas.
  class TransformationRunsController < ApplicationController
    before_action :authenticate_admin!
    before_action :set_run

    def approve
      @run.approve!
      redirect_back_or_to workflow_return_path, notice: "Approved."
    rescue RuntimeError => e
      redirect_back_or_to workflow_return_path, alert: e.message
    end

    def reject
      @run.reject!
      redirect_back_or_to workflow_return_path, notice: "Rejected."
    rescue RuntimeError => e
      redirect_back_or_to workflow_return_path, alert: e.message
    end

    private

      def set_run
        @run = TransformationRun.find(params[:id])
        raise ActiveRecord::RecordNotFound unless @run.result.try(:user) == Current.account
      end

      def workflow_return_path
        return root_path unless @run.workflow_run

        workflow_path(@run.workflow_run.workflow, run: @run.workflow_run_id, node: @run.workflow_node_id)
      end
  end
end
