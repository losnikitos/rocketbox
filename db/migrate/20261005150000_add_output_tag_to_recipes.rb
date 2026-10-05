class AddOutputTagToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_reference :recipes, :output_tag, foreign_key: { to_table: :tags, on_delete: :nullify }
  end
end
