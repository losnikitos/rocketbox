class AddFreshaCalendarToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :fresha_calendar, :json
  end
end
