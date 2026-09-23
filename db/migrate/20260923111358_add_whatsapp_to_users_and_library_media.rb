# frozen_string_literal: true

class AddWhatsappToUsersAndLibraryMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :whatsapp_phone, :string
    add_index :users, :whatsapp_phone

    change_column_null :library_media, :telegram_file_id, true
    change_column_null :library_media, :telegram_file_unique_id, true

    add_column :library_media, :whatsapp_media_id, :string
    add_column :library_media, :whatsapp_from, :string
    add_index :library_media, :whatsapp_media_id, unique: true
  end
end
