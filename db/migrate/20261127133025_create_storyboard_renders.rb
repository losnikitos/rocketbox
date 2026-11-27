# frozen_string_literal: true

class CreateStoryboardRenders < ActiveRecord::Migration[8.1]
  def change
    create_table :storyboard_renders do |t|
      t.string :storyboard_slug, null: false
      t.integer :video_index, null: false, default: 0
      t.string :status, null: false, default: "pending"
      t.text :error

      t.timestamps
    end
    add_index :storyboard_renders, %i[storyboard_slug video_index]
  end
end
