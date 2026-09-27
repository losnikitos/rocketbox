class CreateCrawls < ActiveRecord::Migration[8.1]
  def change
    create_table :crawls do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :provider, null: false
      t.text :data_instruction, null: false
      t.string :status, null: false, default: "pending"
      t.text :error
      t.json :extracted
      t.string :screenshot_url
      t.timestamps
    end

    add_column :library_media, :source_url, :string
    add_index :library_media, [ :user_id, :source_url ]
  end
end
