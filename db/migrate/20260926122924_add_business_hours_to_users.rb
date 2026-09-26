class AddBusinessHoursToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :business_hours, :text
  end
end
