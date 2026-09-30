class CreateGenerations < ActiveRecord::Migration[8.1]
  def change
    create_table :generations do |t|
      t.references :source_media, null: false, foreign_key: { to_table: :library_media }
      t.references :recipe, null: false, foreign_key: true
      t.references :generated_media, foreign_key: { to_table: :library_media }, index: { unique: true }
      t.timestamps
    end
  end
end
