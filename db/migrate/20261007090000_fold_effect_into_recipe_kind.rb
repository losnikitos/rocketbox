# frozen_string_literal: true

# A scripted recipe's effect becomes its kind, the slug of its RecipeType.
class FoldEffectIntoRecipeKind < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE recipes SET kind = replace(effect, '-', '_') WHERE kind = 'scripted'"
    remove_column :recipes, :effect
  end

  def down = raise(ActiveRecord::IrreversibleMigration)
end
