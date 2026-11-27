# frozen_string_literal: true

# Per-storyboard Studio settings: shared overlays/CTA/transition + many videos (source + rules).
class StoryboardSetting < ApplicationRecord
  TRANSITIONS = { "simple_fade" => "Simple fade" }.freeze

  validates :storyboard_slug, presence: true, uniqueness: true
  validates :transition_type, inclusion: { in: TRANSITIONS.keys }
  validate :videos_have_sources

  def self.for(storyboard)
    find_or_initialize_by(storyboard_slug: storyboard.slug).tap do |row|
      next if row.persisted?

      row.assign_attributes(storyboard.default_settings)
    end
  end

  def storyboard = Storyboard.find(storyboard_slug)

  def overlay_text(number)
    overlays.find { it["number"].to_i == number.to_i }&.dig("text").to_s
  end

  def video_at(index)
    videos[index.to_i] || videos.first || { "source" => "", "rules" => [] }
  end

  private

    def videos_have_sources
      videos.each_with_index do |video, i|
        errors.add(:videos, "video #{i + 1} needs a source image") if video["source"].to_s.strip.blank?
      end
    end
end
