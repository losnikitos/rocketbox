# frozen_string_literal: true

class AddNoteToWorkflowNodes < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_nodes, :note, :text
    add_column :workflow_nodes, :color, :string, default: "amber", null: false
  end
end
