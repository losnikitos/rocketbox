# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :tags, :name, unique: true

    create_join_table :library_media, :tags do |t|
      t.index %i[library_media_id tag_id], unique: true
      t.index :tag_id
    end
    add_foreign_key :library_media_tags, :library_media, on_delete: :cascade
    add_foreign_key :library_media_tags, :tags, on_delete: :cascade

    add_column :recipes, :output_tag_ids, :json, default: [], null: false
  end
end
