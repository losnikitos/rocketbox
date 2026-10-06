class AddLayerStepsToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :layer_steps, :json, default: [], null: false
  end
end
