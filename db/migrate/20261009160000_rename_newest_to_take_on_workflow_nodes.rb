# frozen_string_literal: true

class RenameNewestToTakeOnWorkflowNodes < ActiveRecord::Migration[8.1]
  def change
    rename_column :workflow_nodes, :newest, :take
  end
end
