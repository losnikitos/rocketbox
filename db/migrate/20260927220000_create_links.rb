class CreateLinks < ActiveRecord::Migration[8.1]
  def up
    create_table :links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :source, null: false, default: "app"
      t.timestamps
    end
    add_index :links, [ :user_id, :url ], unique: true

    add_reference :crawls, :link, foreign_key: true
    execute <<~SQL
      INSERT INTO links (user_id, url, source, created_at, updated_at)
      SELECT user_id, url, 'app', MIN(created_at), MAX(updated_at) FROM crawls GROUP BY user_id, url
    SQL
    execute <<~SQL
      UPDATE crawls SET link_id = (SELECT id FROM links WHERE links.user_id = crawls.user_id AND links.url = crawls.url)
    SQL
    change_column_null :crawls, :link_id, false
    remove_reference :crawls, :user, foreign_key: true, index: true
    remove_column :crawls, :url
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
