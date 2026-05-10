# frozen_string_literal: true

class AddNotionDatabaseIdToBooks < ActiveRecord::Migration[8.1]
  def up
    add_column :books, :notion_database_id, :string
    add_index :books, :notion_database_id, unique: true

    Book.reset_column_information
    Book.where(slug: "coffeeshop").update_all(
      notion_database_id: "35c875f54593806c8dd5ffc5f1354320"
    )
  end

  def down
    remove_index :books, :notion_database_id
    remove_column :books, :notion_database_id
  end
end
