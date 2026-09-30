class AddCollectionToLibraryMedia < ActiveRecord::Migration[8.1]
  def change
    add_column :library_media, :collection, :string, null: false, default: "inbox"
  end
end
