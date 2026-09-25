# frozen_string_literal: true

class CreateMediaGenerations < ActiveRecord::Migration[8.1]
  def change
    create_table :media_generations do |t|
      t.string :media_type, null: false
      t.string :model, null: false
      t.text :prompt, null: false
      t.integer :status, null: false, default: 0
      t.text :error_message
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :media_generations, [ :status, :created_at ]
  end
end
