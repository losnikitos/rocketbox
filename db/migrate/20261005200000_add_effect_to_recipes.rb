class AddEffectToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :effect, :string, null: false, default: "default"
  end
end
