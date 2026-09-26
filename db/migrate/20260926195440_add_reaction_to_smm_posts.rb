class AddReactionToSmmPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :smm_posts, :reaction, :string
    add_column :smm_posts, :reaction_comment, :text
  end
end
