class DropWaitlistEntries < ActiveRecord::Migration[8.1]
  def change
    drop_table :waitlist_entries do |t|
      t.string :business_link
      t.string :email
      t.string :phone

      t.timestamps
    end
  end
end
