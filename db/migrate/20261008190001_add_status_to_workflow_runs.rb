class AddStatusToWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_runs, :status, :string, default: "draft", null: false
  end
end
