# frozen_string_literal: true

class AddLibraryMediaToWorkflowNodes < ActiveRecord::Migration[8.1]
  def change
    add_reference :workflow_nodes, :library_media, foreign_key: { on_delete: :cascade }
  end
end
