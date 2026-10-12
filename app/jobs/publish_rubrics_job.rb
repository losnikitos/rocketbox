# frozen_string_literal: true

# Runs every rubric due to post (see config/recurring.yml).
class PublishRubricsJob < ApplicationJob
  queue_as :default

  def perform
    Rubric.where(auto_publish: true, next_run_at: ..Time.current).find_each(&:run!)
  end
end
