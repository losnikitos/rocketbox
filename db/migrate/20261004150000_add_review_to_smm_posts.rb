class AddReviewToSmmPosts < ActiveRecord::Migration[8.1]
  def change
    add_reference :smm_posts, :review, foreign_key: { on_delete: :nullify }
  end
end
