# frozen_string_literal: true

class CreatePostFrames < ActiveRecord::Migration[8.1]
  def change
    create_table :post_frames do |t|
      t.references :post, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :rule_number, null: false

      t.timestamps
    end
    add_index :post_frames, [ :post_id, :position ], unique: true
  end
end
