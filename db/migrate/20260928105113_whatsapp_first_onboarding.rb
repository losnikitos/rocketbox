class WhatsappFirstOnboarding < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :email, true
    add_column :users, :whatsapp_pending_question, :string
    add_column :users, :whatsapp_login_at, :datetime
    remove_index :users, :whatsapp_connect_code, unique: true
    remove_column :users, :whatsapp_connect_code, :string
  end
end
