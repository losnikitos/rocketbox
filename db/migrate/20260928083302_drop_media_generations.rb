class DropMediaGenerations < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:active_storage_attachments)
      execute <<-SQL.squish
        DELETE FROM active_storage_attachments
        WHERE record_type = 'MediaGeneration'
      SQL
    end

    drop_table :media_generations, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
