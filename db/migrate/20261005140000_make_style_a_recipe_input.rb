class MakeStyleARecipeInput < ActiveRecord::Migration[8.1]
  def up
    add_column :recipes, :takes_style, :boolean, default: false, null: false
    add_reference :recipe_runs, :style, foreign_key: { on_delete: :nullify }
    execute "UPDATE recipes SET takes_style = 1 WHERE json_extract(options, '$.style') IS NOT NULL"
    execute <<~SQL
      UPDATE recipe_runs SET style_id = CAST(json_extract(options, '$.style') AS INTEGER)
      WHERE json_extract(options, '$.style') IN (SELECT CAST(id AS TEXT) FROM styles)
    SQL
    execute "UPDATE recipes SET options = json_remove(options, '$.style')"
    execute "UPDATE recipe_runs SET options = json_remove(options, '$.style')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
