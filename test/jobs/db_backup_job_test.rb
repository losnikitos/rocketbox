# frozen_string_literal: true

require "test_helper"

class DbBackupJobTest < ActiveJob::TestCase
  # VACUUM INTO can't run inside the transaction transactional tests open.
  self.use_transactional_tests = false

  FakeObject = Struct.new(:key, :last_modified, :uploads, :deleted) do
    def upload_file(path) = uploads[key] = ActiveSupport::Gzip.decompress(File.binread(path))
    def delete = self.deleted = true
  end

  FakeBucket = Struct.new(:existing, :uploads) do
    def object(key) = FakeObject.new(key, Time.current, uploads)
    def objects(prefix:) = existing.select { |o| o.key.start_with?(prefix) }
  end

  test "uploads a gzipped SQLite snapshot and prunes backups older than 7 days" do
    fresh = FakeObject.new("rocketbox/backups/fresh.sqlite3.gz", 1.day.ago)
    stale = FakeObject.new("rocketbox/backups/stale.sqlite3.gz", 8.days.ago)
    bucket = FakeBucket.new([ fresh, stale ], {})
    service = ActiveStorage::Blob.service
    service.define_singleton_method(:bucket) { bucket }

    DbBackupJob.perform_now

    key, data = bucket.uploads.sole
    assert key.start_with?("rocketbox/backups/production-")
    assert data.start_with?("SQLite format 3\0")
    assert stale.deleted
    assert_not fresh.deleted
  ensure
    service.singleton_class.remove_method(:bucket) if service&.singleton_class&.method_defined?(:bucket)
  end
end
