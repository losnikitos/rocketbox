# frozen_string_literal: true

# One generated key frame for a Studio Post (v1, v2, …). Today: rule + image gen; other generators later.
class PostFrame < ApplicationRecord
  belongs_to :post, inverse_of: :frames
  has_one_attached :file

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :post_id }
  validates :rule_number, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Resolvable ref for Storyboard preview / Ferrum / ffmpeg (parallel to /app/media_bank/:id).
  def source_ref = "post_frame/#{id}"
end
