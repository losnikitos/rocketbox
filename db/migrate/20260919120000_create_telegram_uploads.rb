# frozen_string_literal: true

class CreateTelegramUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :telegram_uploads do |t|
      t.string :telegram_file_id, null: false
      t.string :telegram_file_unique_id, null: false
      t.integer :chat_id
      t.integer :from_id
      t.string :kind, null: false

      t.timestamps
    end

    add_index :telegram_uploads, :telegram_file_unique_id, unique: true
  end
end
