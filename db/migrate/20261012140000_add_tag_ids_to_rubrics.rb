# frozen_string_literal: true

class AddTagIdsToRubrics < ActiveRecord::Migration[8.1]
  def change
    add_column :rubrics, :tag_ids, :json, default: [], null: false
  end
end
