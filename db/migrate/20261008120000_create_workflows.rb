# frozen_string_literal: true

class CreateWorkflows < ActiveRecord::Migration[8.1]
  def change
    create_table :workflows do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :workflow_nodes do |t|
      t.references :workflow, null: false, foreign_key: { on_delete: :cascade }
      t.references :folder, foreign_key: true
      t.references :transformation, foreign_key: true
      t.integer :x, null: false, default: 0
      t.integer :y, null: false, default: 0
      t.timestamps
    end

    create_table :workflow_edges do |t|
      t.references :workflow, null: false, foreign_key: { on_delete: :cascade }
      t.references :from, null: false, foreign_key: { to_table: :workflow_nodes, on_delete: :cascade }
      t.references :to, null: false, foreign_key: { to_table: :workflow_nodes, on_delete: :cascade }
      t.timestamps
      t.index %i[from_id to_id], unique: true
    end
  end
end
