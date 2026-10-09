# frozen_string_literal: true

class AddPinnedMediaIdsToWorkflowNodes < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_nodes, :pinned_media_ids, :json, default: [], null: false
  end
end
