class CreateShots < ActiveRecord::Migration[8.1]
  def change
    create_table :shots do |t|
      t.string :name, null: false
      t.text :body, null: false
      t.string :group, null: false, default: "Daily"
      t.timestamps
    end
    add_column :recipes, :shot_group, :string
    add_reference :smm_posts, :shot, foreign_key: true
  end
end
