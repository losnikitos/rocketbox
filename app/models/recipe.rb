# frozen_string_literal: true

# A template for a Ready image: a prompt that composes one image from several photobank photos, one per slot, plus example media.
# `tag_ids` lists the slots in order and may repeat a tag (two staff photos).
# `options` are the defaults for its runs (see GenerationOptions).
# ponytail: slots are a JSON array, so deleting a tag leaves a recipe slot pointing at nothing
# (the recipe then fails validation on edit). Upgrade = a recipe_slots join table with a foreign key.
class Recipe < ApplicationRecord
  include GenerationOptions

  # Runs outlive their recipe.
  has_many :runs, class_name: "RecipeRun", dependent: :nullify
  has_many_attached :examples

  before_validation { self.tag_ids = Array(tag_ids).compact_blank.map(&:to_i) }
  # The shot group its runs pick a shot from; nil takes no shot.
  normalizes :shot_group, with: ->(value) { value.strip.presence }

  validates :name, :body, :tag_ids, presence: true
  validate do
    errors.add(:tag_ids, "include an unknown tag") unless Tag.where(id: tag_ids).count == tag_ids.uniq.size
  end

  scope :ordered, -> { order(:name) }

  def video? = false

  def styled? = true

  def tags = Tag.where(id: tag_ids).index_by(&:id).values_at(*tag_ids)

  # `media` are photobank media in slot order; `shot` is from the recipe's shot group; `options` override the recipe's.
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot doesn't fit or an option isn't available.
  def run!(user:, media:, shot: nil, options: {})
    runs.new(shot:, options:, source_media_ids: media.map(&:id),
      generated_media: user.library_media.new(kind: "photo", collection: "ready")).start!
  end
end
