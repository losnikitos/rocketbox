class ReplaceTagsWithFolders < ActiveRecord::Migration[8.1]
  def up
    rename_table :tags, :folders
    remove_index :folders, :slug
    add_reference :folders, :parent, foreign_key: { to_table: :folders }
    add_index :folders, %i[parent_id slug], unique: true

    tag_ids = select_values("SELECT id FROM folders")
    inbox, photobank, ready = %w[inbox photobank ready].map do |slug|
      insert("INSERT INTO folders (name, slug, created_at, updated_at) VALUES (#{quote(slug.humanize)}, #{quote(slug)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
    end
    execute "UPDATE folders SET parent_id = #{inbox} WHERE id IN (#{tag_ids.join(",")})" if tag_ids.any?
    execute <<~SQL
      INSERT INTO folders (name, slug, parent_id, created_at, updated_at)
      SELECT name, slug, #{photobank}, created_at, updated_at FROM folders WHERE parent_id = #{inbox}
    SQL
    # The tag's copy under `root`, by slug.
    child = "(SELECT f.id FROM folders f JOIN folders t ON t.slug = f.slug WHERE t.id = %s AND f.parent_id = %s)"

    add_reference :library_media, :folder, foreign_key: true
    execute <<~SQL
      UPDATE library_media SET folder_id = CASE collection
        WHEN 'ready' THEN #{ready}
        WHEN 'photobank' THEN COALESCE(#{format(child, "library_media.tag_id", photobank)}, #{photobank})
        ELSE COALESCE(#{format(child, "library_media.tag_id", inbox)}, #{inbox}) END
    SQL
    change_column_null :library_media, :folder_id, false
    remove_reference :library_media, :tag, foreign_key: { to_table: :folders, on_delete: :nullify }, index: true
    remove_column :library_media, :collection

    add_reference :recipes, :output_folder, foreign_key: { to_table: :folders }
    roots = { "inbox" => inbox, "photobank" => photobank }
    select_rows("SELECT id, inputs, output_collection, output_tag_id FROM recipes").each do |id, inputs, output_collection, output_tag_id|
      folder_ids = JSON.parse(inputs).filter_map do |slot|
        root = roots[slot["collection"]]
        root && select_value("SELECT #{format(child, slot["tag_id"].to_i, root)}")
      end
      output = output_collection == "photobank" ? (select_value("SELECT #{format(child, output_tag_id.to_i, photobank)}") || photobank) : ready
      execute "UPDATE recipes SET inputs = #{quote(folder_ids.map { { "folder_id" => it } }.to_json)}, output_folder_id = #{output} WHERE id = #{id}"
    end
    change_column_null :recipes, :output_folder_id, false
    remove_reference :recipes, :output_tag, foreign_key: { to_table: :folders, on_delete: :nullify }, index: true
    remove_column :recipes, :output_collection
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
