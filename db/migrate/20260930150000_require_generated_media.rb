class RequireGeneratedMedia < ActiveRecord::Migration[8.1]
  def up
    Generation.where(generated_media_id: nil).includes(:source_media).find_each do |generation|
      source = generation.source_media
      media = LibraryMedia.create!(user: source.user, kind: "photo", collection: "photobank", media_type: source.media_type)
      generation.update_columns(generated_media_id: media.id)
    end
    change_column_null :generations, :generated_media_id, false
  end

  def down
    change_column_null :generations, :generated_media_id, true
  end
end
