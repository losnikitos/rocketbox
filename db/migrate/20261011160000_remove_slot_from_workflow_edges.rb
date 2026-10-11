# frozen_string_literal: true

class RemoveSlotFromWorkflowEdges < ActiveRecord::Migration[8.1]
  def change
    remove_column :workflow_edges, :slot, :string
  end
end
