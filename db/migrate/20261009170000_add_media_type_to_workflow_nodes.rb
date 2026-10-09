# frozen_string_literal: true

class AddMediaTypeToWorkflowNodes < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_nodes, :media_type, :string
  end
end
