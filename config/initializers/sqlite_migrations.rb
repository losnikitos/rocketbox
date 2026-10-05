# frozen_string_literal: true

# SQLite rebuilds a table for add_reference with a foreign key, rename_column, change_column_default, remove_column, ...
# and ignores `PRAGMA foreign_keys = OFF` inside a transaction, so the rebuild's DROP TABLE fires every on_delete action
# (cascade deletes, nullified references). Turn foreign keys off before each migration's transaction opens instead,
# and fail the migration if it leaves dangling references.
module SqliteMigrationForeignKeys
  private
    def ddl_transaction(migration)
      return super unless connection.adapter_name == "SQLite"

      connection.execute("PRAGMA foreign_keys = OFF")
      super(migration) do
        yield
        connection.check_all_foreign_keys_valid!
      end
    ensure
      connection.execute("PRAGMA foreign_keys = ON") if connection.adapter_name == "SQLite"
    end
end

ActiveSupport.on_load(:active_record) { ActiveRecord::Migrator.prepend(SqliteMigrationForeignKeys) }
