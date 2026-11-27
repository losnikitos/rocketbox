# frozen_string_literal: true

class CreatePostsAndPostRenders < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :name, null: false, default: ""
      t.string :storyboard_slug, null: false
      t.string :source, null: false, default: ""
      t.json :rules, null: false, default: []

      t.timestamps
    end
    add_index :posts, :storyboard_slug

    create_table :post_renders do |t|
      t.references :post, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :error

      t.timestamps
    end
  end
end
