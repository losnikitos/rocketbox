# frozen_string_literal: true

# Runs a TransformationRun.
class GenerateJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(record) { record }, duration: 15.minutes
  discard_on ActiveJob::DeserializationError

  def perform(record)
    record.run!
  end
end
