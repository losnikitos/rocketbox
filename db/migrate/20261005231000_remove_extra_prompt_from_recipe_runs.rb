class RemoveExtraPromptFromRecipeRuns < ActiveRecord::Migration[8.1]
  def change
    remove_column :recipe_runs, :extra_prompt, :text
  end
end
