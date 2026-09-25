# frozen_string_literal: true

class Prompt < ApplicationRecord
  has_many :smm_posts, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :body, presence: true
  validates :position, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def self.library
    active.ordered
  end
end
