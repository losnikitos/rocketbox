# frozen_string_literal: true

# Studio promo video config: references a coded Preset, holds source image + rules.
# Previewed scene-by-scene in Studio; rendered to MP4 via PostRender.
class Post < ApplicationRecord
  has_many :renders, class_name: "PostRender", dependent: :destroy, inverse_of: :post
  has_many :frames, -> { order(:position) }, class_name: "PostFrame", dependent: :destroy, inverse_of: :post

  validates :preset_slug, presence: true
  validate :preset_exists

  after_update :invalidate_derived!, if: -> { saved_change_to_source? || saved_change_to_rules? }

  def preset = Preset.find(preset_slug)

  def scenes = preset.scenes_for(self)

  def find_scene(slug) = preset.find_scene(slug, post: self)

  def rules_list = Array(rules).map(&:to_i)

  def frame_at(position) = frames.find_by(position:)

  # Studio Media bank item chosen as v0 (`posts.source` stores its id).
  def source_media
    id = source.to_s.presence or return
    LibraryMedia.bank.find_by(id:)
  end

  def invalidate_derived!
    frames.destroy_all
    renders.destroy_all
  end

  def self.ensure_defaults!
    Preset::ALL.each do |preset|
      post = find_by(preset_slug: preset.slug) || create!(preset.default_post_attrs)
      post.seed_demo_frames!
    end
  end

  # Guide-promo compare stills so the default film strip has v1/v2 without generation.
  def seed_demo_frames!
    return if frames.exists?

    dir = Rails.root.join("public/guides/#{preset.guide_slug}")
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

    def preset_exists
      Preset.find(preset_slug)
    rescue ActiveRecord::RecordNotFound
      errors.add(:preset_slug, "is not a known preset")
    end
end
