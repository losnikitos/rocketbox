class AddBrandVoiceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :brand_voice, :string
  end
end
