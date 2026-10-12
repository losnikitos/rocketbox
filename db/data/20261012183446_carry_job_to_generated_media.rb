# frozen_string_literal: true

# Generated media take the job of the first source media that has one; id order fills chains parent first.
class CarryJobToGeneratedMedia < ActiveRecord::Migration[8.1]
  def up
    LibraryMedia.where(job_id: nil).where.associated(:transformation_runs).distinct.order(:id).each do |media|
      job_id = media.transformation_run.source_media.filter_map(&:job_id).first
      media.update_column(:job_id, job_id) if job_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
