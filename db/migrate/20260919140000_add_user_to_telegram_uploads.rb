# frozen_string_literal: true

class AddUserToTelegramUploads < ActiveRecord::Migration[8.1]
  def change
    add_reference :telegram_uploads, :user, null: true, foreign_key: true, index: true
  end
end
