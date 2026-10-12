class AddPostsCountToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :posts_count, :integer, default: 0, null: false
  end
end
