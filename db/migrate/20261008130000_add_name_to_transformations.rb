# frozen_string_literal: true

# Transformations are named; existing ones take their recipe's name, or their id.
class AddNameToTransformations < ActiveRecord::Migration[8.1]
  def up
    add_column :transformations, :name, :string
    execute <<~SQL
      UPDATE transformations SET name = COALESCE(
        (SELECT name FROM recipes WHERE recipes.transformation_id = transformations.id ORDER BY recipes.id LIMIT 1),
        'Transformation ' || id)
    SQL
    change_column_null :transformations, :name, false
  end

  def down = remove_column(:transformations, :name)
end
