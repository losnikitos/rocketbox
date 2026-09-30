# frozen_string_literal: true

class GenerateJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(generation_id) { generation_id }, duration: 15.minutes
  discard_on ActiveRecord::RecordNotFound

  def perform(generation_id)
    Generation.find(generation_id).run!
  end
end
