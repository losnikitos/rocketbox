# frozen_string_literal: true

# Versions show the same customer as the media they were made from, so they take its job.
class AssignVersionsTheirSourceJob < ActiveRecord::Migration[8.1]
  def up
    LibraryMedia.where(job_id: nil).find_each do |media|
      job_id = media.original.job_id
      media.update!(job_id:) if job_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
