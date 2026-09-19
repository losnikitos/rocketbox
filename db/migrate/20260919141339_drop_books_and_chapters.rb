class DropBooksAndChapters < ActiveRecord::Migration[8.0]
  def up
    # Purge chapter embedded_images so ActiveStorage blobs are not orphaned.
    if table_exists?(:active_storage_attachments)
      execute <<-SQL.squish
        DELETE FROM active_storage_attachments
        WHERE record_type = 'Chapter' AND name = 'embedded_images'
      SQL
    end

    drop_table :chapters, if_exists: true
    drop_table :books, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
