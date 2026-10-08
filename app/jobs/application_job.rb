class ApplicationJob < ActiveJob::Base
  # Jobs live in the separate queue database, so one enqueued mid-transaction could otherwise run before its records exist.
  self.enqueue_after_transaction_commit = true

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
