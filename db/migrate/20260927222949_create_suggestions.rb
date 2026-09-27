class CreateSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :suggestions do |t|
      t.references :crawl, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
  end
end
