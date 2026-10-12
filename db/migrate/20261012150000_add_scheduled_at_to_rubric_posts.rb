# frozen_string_literal: true

class AddScheduledAtToRubricPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :rubric_posts, :scheduled_at, :datetime
    up_only { execute "UPDATE rubric_posts SET scheduled_at = created_at" }
    change_column_null :rubric_posts, :scheduled_at, false
    remove_index :rubric_posts, :rubric_id
    remove_index :rubric_posts, %i[library_media_id created_at]
    add_index :rubric_posts, %i[rubric_id scheduled_at]
    add_index :rubric_posts, %i[library_media_id scheduled_at]
  end
end
