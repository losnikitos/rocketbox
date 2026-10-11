# frozen_string_literal: true

class RenamePinnedMediaIdsToPinnedIds < ActiveRecord::Migration[8.1]
  def change
    rename_column :workflow_nodes, :pinned_media_ids, :pinned_ids
  end
end
