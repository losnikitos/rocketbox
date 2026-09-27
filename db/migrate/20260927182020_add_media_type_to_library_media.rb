class AddMediaTypeToLibraryMedia < ActiveRecord::Migration[8.1]
  def change
    add_column :library_media, :media_type, :string
  end
end
