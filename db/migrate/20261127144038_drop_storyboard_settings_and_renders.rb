# frozen_string_literal: true

class DropStoryboardSettingsAndRenders < ActiveRecord::Migration[8.1]
  def change
    drop_table :storyboard_renders do |t|
      t.string :storyboard_slug, null: false
      t.integer :video_index, null: false, default: 0
      t.string :status, null: false, default: "pending"
      t.text :error
      t.timestamps
      t.index %i[storyboard_slug video_index]
    end

    drop_table :storyboard_settings do |t|
      t.string :storyboard_slug, null: false
      t.string :transition_type, null: false, default: "simple_fade"
      t.string :cta_text, null: false, default: ""
      t.string :cta_href, null: false, default: ""
      t.json :overlays, null: false, default: []
      t.json :videos, null: false, default: []
      t.timestamps
      t.index :storyboard_slug, unique: true
    end
  end
end
