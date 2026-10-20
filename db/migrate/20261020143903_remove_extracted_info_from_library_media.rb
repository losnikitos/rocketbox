class RemoveExtractedInfoFromLibraryMedia < ActiveRecord::Migration[8.1]
  def change
    remove_column :library_media, :extracted_info, :json
  end
end
