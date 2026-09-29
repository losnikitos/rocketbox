class CreateRecipesAndMovePrompts < ActiveRecord::Migration[8.1]
  def up
    create_table :recipes do |t|
      t.string :name, null: false
      t.text :prompt, null: false
      t.string :media_type, null: false, default: "reels"
      t.timestamps
    end

    execute <<~SQL
      INSERT INTO recipes (id, name, prompt, media_type, created_at, updated_at)
      SELECT id, name, body, 'reels', created_at, updated_at FROM prompts WHERE key IS NULL
    SQL

    add_reference :smm_posts, :recipe, foreign_key: true
    execute "UPDATE smm_posts SET recipe_id = prompt_id"
    change_column_null :smm_posts, :recipe_id, false
    remove_reference :smm_posts, :prompt, foreign_key: true, index: true

    execute "DELETE FROM prompts WHERE key IS NULL"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
