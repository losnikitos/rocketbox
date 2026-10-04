class CreateFeatureSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :feature_slug, null: false
      t.boolean :enabled, null: false, default: false
      t.references :media_type, foreign_key: { on_delete: :nullify }
      t.string :layer_slug
      t.timestamps
    end
    add_index :feature_settings, %i[user_id feature_slug], unique: true

    add_column :smm_posts, :feature_slug, :string
  end
end
