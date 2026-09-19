# frozen_string_literal: true

class RenameTelegramUploadsToLibraryMedia < ActiveRecord::Migration[8.1]
  def up
    rename_table :telegram_uploads, :library_media

    ActiveStorage::Attachment.where(record_type: "TelegramUpload").update_all(record_type: "LibraryMedia")
  end

  def down
    ActiveStorage::Attachment.where(record_type: "LibraryMedia").update_all(record_type: "TelegramUpload")

    rename_table :library_media, :telegram_uploads
  end
end
