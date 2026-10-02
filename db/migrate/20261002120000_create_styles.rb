class CreateStyles < ActiveRecord::Migration[8.1]
  def change
    create_table :styles do |t|
      t.string :name, null: false
      t.text :body, null: false
      t.timestamps
    end
  end
end
