class AddBusinessCardExtraction < ActiveRecord::Migration[8.1]
  def change
    add_column :library_media, :extracted_info, :json
    add_column :users, :phone, :string
    add_column :users, :business_description, :text
    add_column :prompts, :key, :string
    add_index :prompts, :key, unique: true
  end
end
