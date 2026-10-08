# frozen_string_literal: true

class AddPicksToWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_runs, :picks, :json, default: {}, null: false
  end
end
