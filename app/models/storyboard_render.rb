# frozen_string_literal: true

# One finished (or in-flight) MP4 for a storyboard video index.
class StoryboardRender < ApplicationRecord
  STATUSES = %w[pending running done failed].freeze

  has_one_attached :file

  enum :status, STATUSES.index_by(&:itself), default: :pending

  validates :storyboard_slug, :video_index, presence: true

  def storyboard = Storyboard.find(storyboard_slug)

  def settings = StoryboardSetting.for(storyboard)

  def video = settings.video_at(video_index)

  def filename = "#{storyboard_slug}-v#{video_index}.mp4"
end
