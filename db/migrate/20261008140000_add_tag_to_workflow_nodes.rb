# frozen_string_literal: true

class AddTagToWorkflowNodes < ActiveRecord::Migration[8.1]
  def change
    add_reference :workflow_nodes, :tag, foreign_key: { on_delete: :nullify }
  end
end
