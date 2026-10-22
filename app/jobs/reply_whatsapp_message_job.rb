# frozen_string_literal: true

class ReplyWhatsappMessageJob < ApplicationJob
  queue_as :default

  def perform(payload)
    ReplyWhatsappMessage.call(payload)
  end
end
