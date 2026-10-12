# frozen_string_literal: true

class BackfillJobPostsCount < ActiveRecord::Migration[8.1]
  def up
    Job.find_each { it.update_columns(posts_count: RubricPost.joins(:library_media).where(library_media: { job_id: it.id }).count) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
