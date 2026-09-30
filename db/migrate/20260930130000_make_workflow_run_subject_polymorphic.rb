class MakeWorkflowRunSubjectPolymorphic < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :workflow_runs, :smm_posts
    remove_index :workflow_runs, :smm_post_id
    rename_column :workflow_runs, :smm_post_id, :subject_id
    add_column :workflow_runs, :subject_type, :string, null: false, default: "SmmPost"
    change_column_default :workflow_runs, :subject_type, from: "SmmPost", to: nil
    add_index :workflow_runs, %i[subject_type subject_id]
  end
end
