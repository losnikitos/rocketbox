# frozen_string_literal: true

class Document < ApplicationRecord
  extend FriendlyId

  friendly_id :name, use: %i[finders slugged]

  validates :name, presence: true
  validates :title, presence: true

  scope :published, -> { where(published: true) }
end
