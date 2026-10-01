class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :name, null: false
      t.text :body, null: false
      t.string :format, null: false, default: "post"
      t.json :media_type_ids, null: false, default: []
      t.timestamps
    end
    add_reference :smm_posts, :recipe, foreign_key: true
  end
end
