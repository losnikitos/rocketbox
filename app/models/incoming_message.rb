# frozen_string_literal: true

class IncomingMessage < ApplicationRecord
  belongs_to :user, optional: true

  validates :channel, presence: true
  validates :payload, presence: true
end
