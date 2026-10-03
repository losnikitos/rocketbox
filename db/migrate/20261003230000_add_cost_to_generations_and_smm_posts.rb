class AddCostToGenerationsAndSmmPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :cost, :decimal, precision: 10, scale: 6
    add_column :smm_posts, :cost, :decimal, precision: 10, scale: 6
  end
end
