# frozen_string_literal: true

# Workflows replace recipes. Transformations no workflow step owns go too: nothing runs them any more.
class DropRecipes < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM friendly_id_slugs WHERE sluggable_type = 'Recipe'"
    remove_reference :transformation_runs, :recipe, foreign_key: { on_delete: :nullify }, index: true
    drop_table :recipes
    drop_table :recipe_folders
    orphans = "SELECT id FROM transformations WHERE id NOT IN (SELECT transformation_id FROM workflow_nodes WHERE transformation_id IS NOT NULL)"
    execute "UPDATE transformation_runs SET transformation_id = NULL WHERE transformation_id IN (#{orphans})"
    execute "DELETE FROM transformations WHERE id IN (#{orphans})"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
