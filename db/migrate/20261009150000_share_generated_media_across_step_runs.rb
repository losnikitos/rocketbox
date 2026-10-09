# frozen_string_literal: true

class ShareGeneratedMediaAcrossStepRuns < ActiveRecord::Migration[8.1]
  def change
    remove_index :transformation_runs, :generated_media_id, unique: true
    add_index :transformation_runs, :generated_media_id
  end
end
