# frozen_string_literal: true

class CreateSmmPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :smm_posts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :prompt, null: false, foreign_key: true
      t.string :status, null: false, default: "draft"
      t.text :caption
      t.text :error_message
      t.string :generation_request_id
      t.datetime :published_at

      t.timestamps
    end

    add_index :smm_posts, :status
    add_index :smm_posts, [ :user_id, :created_at ]
  end
end
