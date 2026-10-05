require "test_helper"

class SqliteMigrationsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @conn = ActiveRecord::Base.connection
    @conn.create_table(:fk_parents) { |t| t.integer :recipe_id }
    @conn.create_table(:fk_children) { |t| t.references :fk_parent, null: false, foreign_key: { on_delete: :cascade } }
    @conn.execute("INSERT INTO fk_parents (id, recipe_id) VALUES (1, 7)")
    @conn.execute("INSERT INTO fk_children (fk_parent_id) VALUES (1)")
  end

  teardown do
    @conn.drop_table(:fk_children, if_exists: true)
    @conn.drop_table(:fk_parents, if_exists: true)
    @conn.execute("DELETE FROM schema_migrations WHERE version = '1'")
  end

  test "a table rebuild inside a migration transaction keeps child rows" do
    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def up = add_reference(:fk_parents, :tag, foreign_key: { on_delete: :nullify })
    end.new("RebuildParents", 1)

    ActiveRecord::Migrator.new(:up, [ migration ], @conn.pool.schema_migration, @conn.pool.internal_metadata).migrate

    assert_equal 1, @conn.select_value("SELECT COUNT(*) FROM fk_children")
    assert_equal 1, @conn.select_value("PRAGMA foreign_keys")
  end
end
