# frozen_string_literal: true

class ReplaceTagWithTagIdsOnWorkflowNodes < ActiveRecord::Migration[8.1]
  def up
    add_column :workflow_nodes, :tag_ids, :json, default: [], null: false
    execute "UPDATE workflow_nodes SET tag_ids = json_array(tag_id) WHERE tag_id IS NOT NULL"
    remove_reference :workflow_nodes, :tag, foreign_key: { on_delete: :nullify }
  end

  def down
    add_reference :workflow_nodes, :tag, foreign_key: { on_delete: :nullify }
    execute "UPDATE workflow_nodes SET tag_id = json_extract(tag_ids, '$[0]')"
    remove_column :workflow_nodes, :tag_ids
  end
end
