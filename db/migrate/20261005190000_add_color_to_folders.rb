class AddColorToFolders < ActiveRecord::Migration[8.1]
  def up
    add_column :folders, :color, :string, null: false, default: "sky"
    execute <<~SQL
      UPDATE folders SET color = 'emerald'
      WHERE id = (SELECT id FROM folders WHERE slug = 'inbox' AND parent_id IS NULL)
         OR parent_id = (SELECT id FROM folders WHERE slug = 'inbox' AND parent_id IS NULL)
    SQL
  end

  def down
    remove_column :folders, :color
  end
end
