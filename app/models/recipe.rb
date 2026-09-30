# frozen_string_literal: true

# How a library media is turned into new content: a prompt for one AI call, example media, and whether it makes an image or a video.
class Recipe < ApplicationRecord
  has_many :generations, dependent: :restrict_with_exception
  has_many_attached :examples

  # The library media this recipe suits.
  enum :media_type, LibraryMedia.media_types, validate: true
  enum :kind, %w[image video].index_by(&:itself), validate: true

  validates :name, :prompt, presence: true

  scope :ordered, -> { order(:name) }
end
