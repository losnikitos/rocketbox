class RenameRecipesToPrompts < ActiveRecord::Migration[8.1]
  def up
    drop_table :prompts
    rename_table :recipes, :prompts
    rename_column :prompts, :prompt, :body
    rename_column :generations, :prompt, :extra_prompt
    rename_column :generations, :recipe_id, :prompt_id
    execute "UPDATE active_storage_attachments SET record_type = 'Prompt' WHERE record_type = 'Recipe'"
    execute "UPDATE active_admin_comments SET resource_type = 'Prompt' WHERE resource_type = 'Recipe'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
