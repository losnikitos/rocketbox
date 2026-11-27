# frozen_string_literal: true

class CreateStoryboardSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :storyboard_settings do |t|
      t.string :storyboard_slug, null: false
      t.string :transition_type, null: false, default: "simple_fade"
      t.string :cta_text, null: false, default: ""
      t.string :cta_href, null: false, default: ""
      t.json :overlays, null: false, default: []
      t.json :videos, null: false, default: []

      t.timestamps
    end
    add_index :storyboard_settings, :storyboard_slug, unique: true
  end
end
