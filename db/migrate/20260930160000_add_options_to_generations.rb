class AddOptionsToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :options, :json, default: {}, null: false
  end
end
