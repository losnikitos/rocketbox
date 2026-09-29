class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :price
      t.string :duration
      t.text :description
      t.timestamps
    end
  end
end
