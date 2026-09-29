# frozen_string_literal: true

# Snapshots the primary SQLite database to S3 (shared festivo bucket, rocketbox/backups/).
# ponytail: full hourly snapshots, so a restore loses up to an hour of writes; switch to Litestream once real users arrive.
class DbBackupJob < ApplicationJob
  queue_as :default

  PREFIX = "rocketbox/backups/"
  RETENTION = 7.days

  def perform
    bucket = ActiveStorage::Blob.service.bucket

    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "backup.sqlite3")
      gz_path = "#{db_path}.gz"

      # WAL mode: copying the live file can be inconsistent; VACUUM INTO writes a clean snapshot.
      ActiveRecord::Base.connection.execute("VACUUM INTO '#{db_path}'")
      Zlib::GzipWriter.open(gz_path) { |gz| File.open(db_path, "rb") { |f| IO.copy_stream(f, gz) } }

      bucket.object("#{PREFIX}production-#{Time.current.utc.iso8601}.sqlite3.gz").upload_file(gz_path)
    end

    bucket.objects(prefix: PREFIX).each { |o| o.delete if o.last_modified < RETENTION.ago }
  end
end
