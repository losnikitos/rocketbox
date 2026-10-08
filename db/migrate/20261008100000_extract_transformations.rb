# frozen_string_literal: true

# A recipe's processing (type, prompt, options, style, shot group, layer steps) moves to a transformation, one per
# recipe under the recipe's id; recipe runs become transformation runs.
class ExtractTransformations < ActiveRecord::Migration[8.1]
  COLUMNS = %w[kind body options style_id shot_group layer_steps created_at updated_at].freeze

  def up
    create_table :transformations do |t|
      t.string :kind, default: "generate_image", null: false
      t.text :body, null: false
      t.json :options, default: {}, null: false
      t.references :style, foreign_key: { on_delete: :nullify }
      t.string :shot_group
      t.json :layer_steps, default: [], null: false
      t.timestamps
    end
    execute "INSERT INTO transformations (id, #{COLUMNS.join(", ")}) SELECT id, #{COLUMNS.join(", ")} FROM recipes"

    add_reference :recipes, :transformation, foreign_key: true
    execute "UPDATE recipes SET transformation_id = id"
    change_column_null :recipes, :transformation_id, false
    remove_reference :recipes, :style, foreign_key: { on_delete: :nullify }, index: true
    remove_columns :recipes, :kind, :body, :options, :shot_group, :layer_steps

    rename_table :recipe_runs, :transformation_runs
    add_reference :transformation_runs, :transformation, foreign_key: { on_delete: :nullify }
    execute "UPDATE transformation_runs SET transformation_id = recipe_id"

    rename_table :recipe_run_inputs, :transformation_run_inputs
    rename_column :transformation_run_inputs, :recipe_run_id, :transformation_run_id
  end

  def down = raise(ActiveRecord::IrreversibleMigration)
end
