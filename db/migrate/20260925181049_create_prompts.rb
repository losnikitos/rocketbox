# frozen_string_literal: true

class CreatePrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :prompts do |t|
      t.string :name, null: false
      t.text :body, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :prompts, :active
    add_index :prompts, :position
  end
end
