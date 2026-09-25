# frozen_string_literal: true

class SmmPostMediaItem < ApplicationRecord
  belongs_to :smm_post, inverse_of: :smm_post_media_items
  belongs_to :library_media

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :library_media_id, uniqueness: { scope: :smm_post_id }
end
