# frozen_string_literal: true

class AddIncludeSubfoldersToWorkflowNodes < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_nodes, :include_subfolders, :boolean, default: true, null: false
  end
end
