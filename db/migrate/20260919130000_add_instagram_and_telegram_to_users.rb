class AddInstagramAndTelegramToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :instagram_user_id, :string
    add_column :users, :instagram_access_token, :text
    add_column :users, :telegram_user_id, :bigint
  end
end
