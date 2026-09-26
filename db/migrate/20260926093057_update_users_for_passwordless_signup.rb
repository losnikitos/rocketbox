class UpdateUsersForPasswordlessSignup < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string
    add_column :users, :business_name, :string
    remove_column :users, :password_digest, :string, null: false
  end
end
