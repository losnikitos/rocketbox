# frozen_string_literal: true

class Prompt < ApplicationRecord
  validates :name, presence: true
  validates :body, presence: true
  validates :position, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }

  validates :key, uniqueness: true, allow_nil: true

  normalizes :key, with: ->(key) { key.presence }

  def self.body_for!(key)
    active.find_by!(key: key.to_s).body
  end
end
