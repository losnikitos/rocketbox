class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.string :customer_name, null: false
      t.integer :rating, null: false
      t.text :body
      t.datetime :archived_at
      t.timestamps
    end
  end
end
