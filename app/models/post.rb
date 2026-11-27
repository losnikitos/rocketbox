# frozen_string_literal: true

# Studio promo video config: references a coded Storyboard preset, holds source image + rules.
# Previewed scene-by-scene in Studio; rendered to MP4 via PostRender.
class Post < ApplicationRecord
  has_many :renders, class_name: "PostRender", dependent: :destroy, inverse_of: :post

  validates :storyboard_slug, presence: true
  validates :name, presence: true
  validate :storyboard_exists

  def storyboard = Storyboard.find(storyboard_slug)

  def scenes = storyboard.scenes_for(self)

  def find_scene(slug) = storyboard.find_scene(slug, post: self)

  def rules_list = Array(rules).map(&:to_i)

  def self.ensure_defaults!
    Storyboard::ALL.each do |board|
      next if exists?(storyboard_slug: board.slug)

      create!(board.default_post_attrs)
    end
  end

  private

    def storyboard_exists
      Storyboard.find(storyboard_slug)
    rescue ActiveRecord::RecordNotFound
      errors.add(:storyboard_slug, "is not a known storyboard")
    end
end
