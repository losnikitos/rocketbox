# frozen_string_literal: true

class AddInputToWorkflowEdges < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_edges, :input, :string, null: false, default: ""
  end
end
