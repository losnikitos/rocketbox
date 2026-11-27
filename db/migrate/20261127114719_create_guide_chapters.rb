# frozen_string_literal: true

class CreateGuideChapters < ActiveRecord::Migration[8.1]
  def change
    create_table :guide_chapters do |t|
      t.references :guide, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :body, null: false, default: ""
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :guide_chapters, %i[guide_id slug], unique: true
  end
end
