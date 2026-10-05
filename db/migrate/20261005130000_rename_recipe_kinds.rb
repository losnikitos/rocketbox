class RenameRecipeKinds < ActiveRecord::Migration[8.1]
  # SQLite rebuilds the table to change a default; inside a transaction that would fire the on_delete actions.
  disable_ddl_transaction!

  def up
    change_column_default :recipes, :kind, from: "image", to: "generate_image"
    execute "UPDATE recipes SET kind = 'generate_' || kind WHERE kind IN ('image', 'video')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
