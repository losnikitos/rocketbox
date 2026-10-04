class CreateRecipeRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_runs do |t|
      t.references :recipe, foreign_key: { on_delete: :nullify }
      t.references :shot, foreign_key: { on_delete: :nullify }
      t.references :generated_media, null: false, foreign_key: { to_table: :library_media }, index: { unique: true }
      t.json :source_media_ids, null: false, default: []
      t.json :options, null: false, default: {}
      t.text :prompt
      t.decimal :cost, precision: 10, scale: 6
      t.string :status, null: false, default: "running"
      t.text :error
      t.timestamps
    end

    remove_column :recipes, :format, :string, null: false, default: "post"

    remove_reference :smm_posts, :recipe, foreign_key: true, index: true
    remove_reference :smm_posts, :shot, foreign_key: true, index: true
    remove_column :smm_posts, :prompt, :text
    remove_column :smm_posts, :options, :json, null: false, default: {}
    remove_column :smm_posts, :cost, :decimal, precision: 10, scale: 6
  end
end
