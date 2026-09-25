# frozen_string_literal: true

class CreateSmmPostMediaItems < ActiveRecord::Migration[8.1]
  def change
    create_table :smm_post_media_items do |t|
      t.references :smm_post, null: false, foreign_key: true
      t.references :library_media, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :smm_post_media_items, [ :smm_post_id, :library_media_id ], unique: true, name: "index_smm_post_media_items_uniqueness"
    add_index :smm_post_media_items, [ :smm_post_id, :position ]
  end
end
