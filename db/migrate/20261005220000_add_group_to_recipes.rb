class AddGroupToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :group, :string
  end
end
