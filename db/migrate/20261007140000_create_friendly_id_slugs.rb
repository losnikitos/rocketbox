# frozen_string_literal: true

class CreateFriendlyIdSlugs < ActiveRecord::Migration[8.1]
  def change
    create_table :friendly_id_slugs do |t|
      t.string :slug, null: false
      t.integer :sluggable_id, null: false
      t.string :sluggable_type
      t.string :scope
      t.datetime :created_at
    end
    add_index :friendly_id_slugs, %i[sluggable_type sluggable_id]
    add_index :friendly_id_slugs, %i[slug sluggable_type scope], unique: true

    reversible do |dir|
      dir.up { execute "INSERT INTO friendly_id_slugs (slug, sluggable_id, sluggable_type, created_at) SELECT slug, id, 'Recipe', CURRENT_TIMESTAMP FROM recipes" }
    end
  end
end
