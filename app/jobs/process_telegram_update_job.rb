# frozen_string_literal: true

class ProcessTelegramUpdateJob < ApplicationJob
  queue_as :default

  def perform(update)
    StoreTelegramMedia.call(update)
  end
end
