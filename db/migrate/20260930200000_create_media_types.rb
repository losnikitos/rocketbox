class CreateMediaTypes < ActiveRecord::Migration[8.1]
  KEYS = %w[business_card interior exterior logo customer misc].freeze

  def up
    create_table :media_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :media_types, :slug, unique: true

    KEYS.each do |key|
      execute "INSERT INTO media_types (name, slug, created_at, updated_at) VALUES (#{quote(key.humanize)}, #{quote(key.dasherize)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    end

    add_reference :library_media, :media_type, foreign_key: { on_delete: :nullify }
    add_reference :recipes, :media_type, foreign_key: true

    %w[library_media recipes].each do |table|
      execute "UPDATE #{table} SET media_type_id = (SELECT id FROM media_types WHERE media_types.slug = REPLACE(#{table}.media_type, '_', '-'))"
    end

    change_column_null :recipes, :media_type_id, false
    remove_column :library_media, :media_type
    remove_column :recipes, :media_type
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

    def quote(value) = connection.quote(value)
end
