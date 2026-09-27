class AddInstagramProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :instagram_profile, :json
  end
end
