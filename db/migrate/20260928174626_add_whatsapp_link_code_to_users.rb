class AddWhatsappLinkCodeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :whatsapp_link_code, :string
    add_index :users, :whatsapp_link_code, unique: true
  end
end
