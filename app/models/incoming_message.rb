# frozen_string_literal: true

class IncomingMessage < ApplicationRecord
  belongs_to :user, optional: true
  has_many_attached :attachments

  validates :channel, presence: true
  validates :payload, presence: true
end
