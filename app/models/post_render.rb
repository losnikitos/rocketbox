# frozen_string_literal: true

# One finished (or in-flight) MP4 for a Studio Post.
class PostRender < ApplicationRecord
  STATUSES = %w[pending running done failed].freeze

  belongs_to :post, inverse_of: :renders
  has_one_attached :file

  enum :status, STATUSES.index_by(&:itself), default: :pending

  def storyboard = post.storyboard

  def filename = "post-#{post_id}-#{id}.mp4"
end
