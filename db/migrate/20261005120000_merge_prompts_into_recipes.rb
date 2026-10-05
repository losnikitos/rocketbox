class MergePromptsIntoRecipes < ActiveRecord::Migration[8.1]
  # SQLite ignores `PRAGMA foreign_keys = OFF` inside a transaction, so rebuilding a table for remove_column
  # would fire the on_delete actions and wipe recipe_runs.recipe_id, feature_settings.recipe_id and the inputs.
  disable_ddl_transaction!

  def up
    add_column :recipes, :kind, :string, null: false, default: "image"
    add_column :recipes, :inputs, :json, null: false, default: []
    add_column :recipes, :output_collection, :string, null: false, default: "ready"
    add_column :recipe_runs, :extra_prompt, :text
    create_table :recipe_run_inputs do |t|
      t.references :recipe_run, null: false, foreign_key: { on_delete: :cascade }
      t.references :library_media, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0
    end
    add_index :recipe_run_inputs, %i[recipe_run_id position], unique: true

    recipe = Class.new(ActiveRecord::Base) { self.table_name = "recipes" }
    run = Class.new(ActiveRecord::Base) { self.table_name = "recipe_runs" }
    input = Class.new(ActiveRecord::Base) { self.table_name = "recipe_run_inputs" }
    [ recipe, run, input ].each(&:reset_column_information)

    recipe.find_each do |r|
      r.update_columns(inputs: Array(r.tag_ids).map { { "collection" => "photobank", "tag_id" => it } })
    end
    run.find_each do |r|
      Array(r.source_media_ids).each_with_index { |id, position| input.create!(recipe_run_id: r.id, library_media_id: id, position:) }
    end

    recipe_ids = select_rows("SELECT id, name, body, kind, options, tag_id, created_at, updated_at FROM prompts").to_h do |id, name, body, kind, options, tag_id, created_at, updated_at|
      created = recipe.create!(name:, body:, kind:, options: JSON.parse(options), tag_ids: [], output_collection: "photobank",
        inputs: [ { "collection" => "inbox", "tag_id" => tag_id } ], created_at:, updated_at:)
      [ id, created.id ]
    end
    recipe_ids.each do |prompt_id, recipe_id|
      execute "UPDATE active_storage_attachments SET record_type = 'Recipe', record_id = #{recipe_id} WHERE record_type = 'Prompt' AND record_id = #{prompt_id}"
    end

    select_rows("SELECT prompt_id, source_media_id, generated_media_id, extra_prompt, options, status, error, cost, created_at, updated_at FROM generations")
      .each do |prompt_id, source_media_id, generated_media_id, extra_prompt, options, status, error, cost, created_at, updated_at|
      created = run.create!(recipe_id: recipe_ids[prompt_id], generated_media_id:, extra_prompt:, options: JSON.parse(options),
        status:, error:, cost:, source_media_ids: [], created_at:, updated_at:)
      input.create!(recipe_run_id: created.id, library_media_id: source_media_id, position: 0)
    end

    drop_table :generations
    drop_table :prompts
    remove_column :recipes, :tag_ids
    remove_column :recipe_runs, :source_media_ids
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
