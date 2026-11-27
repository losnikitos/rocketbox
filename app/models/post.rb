# frozen_string_literal: true

# Studio promo video config: references a coded Storyboard preset, holds source image + rules.
# Previewed scene-by-scene in Studio; rendered to MP4 via PostRender.
class Post < ApplicationRecord
  has_many :renders, class_name: "PostRender", dependent: :destroy, inverse_of: :post
  has_many :frames, -> { order(:position) }, class_name: "PostFrame", dependent: :destroy, inverse_of: :post

  validates :storyboard_slug, presence: true
  validate :storyboard_exists

  after_update :invalidate_derived!, if: -> { saved_change_to_source? || saved_change_to_rules? }

  def storyboard = Storyboard.find(storyboard_slug)

  def scenes = storyboard.scenes_for(self)

  def find_scene(slug) = storyboard.find_scene(slug, post: self)

  def rules_list = Array(rules).map(&:to_i)

  def frame_at(position) = frames.find_by(position:)

  def invalidate_derived!
    frames.destroy_all
    renders.destroy_all
  end

  def self.ensure_defaults!
    Storyboard::ALL.each do |board|
      post = find_by(storyboard_slug: board.slug) || create!(board.default_post_attrs)
      post.seed_demo_frames!
    end
  end

  # Guide-promo compare stills so the default film strip has v1/v2 without generation.
  def seed_demo_frames!
    return if frames.exists?

    dir = Rails.root.join("public/guides/#{storyboard.guide_slug}")
    [
      [ 1, 10, "clean.jpg" ],
      [ 2, 12, "warm.jpg" ]
    ].each do |position, rule_number, filename|
      file = dir.join(filename)
      next unless file.file?

      frame = frames.create!(position:, rule_number:)
      frame.file.attach(io: File.open(file), filename:, content_type: "image/jpeg")
    end
  end

  private

    def storyboard_exists
      Storyboard.find(storyboard_slug)
    rescue ActiveRecord::RecordNotFound
      errors.add(:storyboard_slug, "is not a known storyboard")
    end
end
