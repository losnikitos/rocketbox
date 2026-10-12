# frozen_string_literal: true

class PublishRubricPostJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(rubric_post)
    rubric_post.publish!
  end
end
