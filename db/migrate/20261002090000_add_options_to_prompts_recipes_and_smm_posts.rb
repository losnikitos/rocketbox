class AddOptionsToPromptsRecipesAndSmmPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :prompts, :options, :json, default: {}, null: false
    add_column :recipes, :options, :json, default: {}, null: false
    add_column :smm_posts, :options, :json, default: {}, null: false
  end
end
