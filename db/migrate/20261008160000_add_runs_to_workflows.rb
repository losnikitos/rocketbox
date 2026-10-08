# frozen_string_literal: true

class AddRunsToWorkflows < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_runs do |t|
      t.references :workflow, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, default: "Draft"
      t.text :error
      t.timestamps
    end

    # Left in some databases' schema by an earlier draft; no migration made it.
    if column_exists?(:transformation_runs, :workflow_id)
      remove_reference :transformation_runs, :workflow, index: true, foreign_key: { on_delete: :nullify }
    end
    add_reference :transformation_runs, :workflow_run, foreign_key: { on_delete: :cascade }
    add_reference :transformation_runs, :workflow_node, foreign_key: { on_delete: :nullify }
  end
end
