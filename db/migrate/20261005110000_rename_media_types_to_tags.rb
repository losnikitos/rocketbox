class RenameMediaTypesToTags < ActiveRecord::Migration[8.1]
  def change
    rename_table :media_types, :tags
    rename_column :library_media, :media_type_id, :tag_id
    rename_column :prompts, :media_type_id, :tag_id
    rename_column :recipes, :media_type_ids, :tag_ids
  end
end
