# frozen_string_literal: true

class Prompt < ApplicationRecord
  has_many :smm_posts, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :body, presence: true
  validates :position, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  validates :key, uniqueness: true, allow_nil: true

  normalizes :key, with: ->(key) { key.presence }

  # Keyed prompts are system prompts, looked up by key rather than picked by users.
  def self.library
    active.where(key: nil).ordered
  end

  def self.body_for!(key)
    active.find_by!(key: key.to_s).body
  end
end
