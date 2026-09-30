class DropWorkflows < ActiveRecord::Migration[8.1]
  def up
    add_column :recipes, :kind, :string, null: false, default: "image"
    execute "UPDATE recipes SET kind = 'video' WHERE workflow = 'ImagesToVideo'"
    remove_column :recipes, :workflow
    remove_column :recipes, :texts

    add_column :generations, :status, :string, null: false, default: "running"
    add_column :generations, :error, :text
    execute <<~SQL
      UPDATE generations SET
        status = (SELECT CASE status WHEN 'running' THEN 'running' WHEN 'complete' THEN 'complete' ELSE 'failed' END
                  FROM workflow_runs WHERE subject_type = 'Generation' AND subject_id = generations.id),
        error = (SELECT error FROM workflow_runs WHERE subject_type = 'Generation' AND subject_id = generations.id)
      WHERE id IN (SELECT subject_id FROM workflow_runs WHERE subject_type = 'Generation')
    SQL

    remove_reference :smm_posts, :recipe, foreign_key: true, index: true

    execute "DELETE FROM active_storage_attachments WHERE record_type = 'WorkflowStep'"
    drop_table :workflow_steps
    drop_table :workflow_runs
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
