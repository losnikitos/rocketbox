# frozen_string_literal: true

# How an SMM media is made: a generation prompt plus example media for the target format.
class Recipe < ApplicationRecord
  has_many :smm_posts, dependent: :restrict_with_exception
  has_many_attached :examples

  enum :media_type, %w[reels story post].index_by(&:itself), validate: true

  validates :name, :prompt, presence: true

  scope :ordered, -> { order(:name) }
end
