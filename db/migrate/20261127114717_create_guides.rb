# frozen_string_literal: true

class CreateGuides < ActiveRecord::Migration[8.1]
  def change
    create_table :guides do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :lede, null: false, default: ""
      t.boolean :published, null: false, default: false

      t.timestamps
    end
    add_index :guides, :slug, unique: true
  end
end
