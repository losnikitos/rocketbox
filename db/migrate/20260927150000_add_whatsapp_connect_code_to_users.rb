class AddWhatsappConnectCodeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :whatsapp_connect_code, :string
    add_index :users, :whatsapp_connect_code, unique: true
  end
end
