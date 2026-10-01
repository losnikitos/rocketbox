# frozen_string_literal: true

# How a library media is turned into new content: a body for one AI call, example media, and whether it makes an image or a video.
class Prompt < ApplicationRecord
  # The library media this prompt suits.
  belongs_to :media_type
  has_many :generations, dependent: :restrict_with_exception
  has_many_attached :examples

  enum :kind, %w[image video].index_by(&:itself), validate: true

  validates :name, :body, presence: true

  scope :ordered, -> { order(:name) }
end
