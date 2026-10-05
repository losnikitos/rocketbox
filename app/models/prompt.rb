# frozen_string_literal: true

# How a library media is turned into new content: a body for one AI call, example media, and whether it makes an image or a video.
# `options` are the defaults for its generations (see GenerationOptions).
class Prompt < ApplicationRecord
  include GenerationOptions

  # The library media this prompt suits.
  belongs_to :tag
  has_many :generations, dependent: :restrict_with_exception
  has_many_attached :examples

  enum :kind, %w[image video].index_by(&:itself), validate: true

  validates :name, :body, presence: true

  scope :ordered, -> { order(:name) }
end
