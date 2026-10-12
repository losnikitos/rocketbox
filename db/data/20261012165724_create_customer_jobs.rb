# frozen_string_literal: true

# Every media in Inbox / Customer gets its own job; same-customer jobs get merged by hand on /app/jobs.
class CreateCustomerJobs < ActiveRecord::Migration[8.1]
  def up
    folder = Folder.inbox.children.find_by(slug: "customer") or return
    LibraryMedia.where(folder:, job_id: nil).where.not(user_id: nil).includes(:user).find_each do |media|
      media.update!(job: media.user.jobs.create!)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
