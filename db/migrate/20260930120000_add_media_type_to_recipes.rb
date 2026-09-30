class AddMediaTypeToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :media_type, :string, null: false, default: "misc"
  end
end
