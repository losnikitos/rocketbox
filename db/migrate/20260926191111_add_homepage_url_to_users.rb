class AddHomepageUrlToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :homepage_url, :string
  end
end
