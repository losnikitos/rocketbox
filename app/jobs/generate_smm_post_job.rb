# frozen_string_literal: true

class GenerateSmmPostJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(smm_post_id) { smm_post_id }, duration: 15.minutes
  discard_on ActiveRecord::RecordNotFound

  def perform(smm_post_id)
    SmmPost.find(smm_post_id).generate!
  end
end
