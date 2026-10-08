# frozen_string_literal: true

class AddSlotAndNewestToWorkflows < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_edges, :slot, :string
    add_column :workflow_nodes, :newest, :integer, default: 1, null: false
  end
end
