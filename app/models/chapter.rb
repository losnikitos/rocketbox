# frozen_string_literal: true

class Chapter < ApplicationRecord
  belongs_to :book, inverse_of: :chapters

  scope :free, -> { where(free: true) }

  validates :title, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :book_id }
end
