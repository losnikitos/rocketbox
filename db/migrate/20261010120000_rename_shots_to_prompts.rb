class RenameShotsToPrompts < ActiveRecord::Migration[8.1]
  def change
    rename_column :transformation_runs, :prompt, :prompt_text
    rename_table :shots, :prompts
    rename_column :prompts, :group, :folder
    change_column_default :prompts, :folder, from: "Daily", to: "Shots"
    rename_column :transformation_runs, :shot_id, :prompt_id
    rename_column :transformations, :shot_group, :prompt_folder
    up_only do
      execute "UPDATE prompts SET folder = 'Shots'"
      execute "UPDATE transformations SET prompt_folder = 'Shots' WHERE prompt_folder IS NOT NULL"
      execute "UPDATE active_storage_attachments SET record_type = 'Prompt' WHERE record_type = 'Shot'"
    end
  end
end
