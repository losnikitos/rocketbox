class MoveReadyUnderPhotobank < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE folders SET parent_id = (SELECT id FROM folders WHERE slug = 'photobank' AND parent_id IS NULL)
      WHERE slug = 'ready' AND parent_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
