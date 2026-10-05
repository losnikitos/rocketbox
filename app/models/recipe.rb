# frozen_string_literal: true

# How media is made: one AI call over library media, one per input slot, plus example media.
# `inputs` lists the slots in order as { "collection", "tag_id" } and may repeat one (two staff photos).
# `kind` is what it makes; results land in `output_collection` with the first input's tag.
# `options` are the defaults for its runs (see GenerationOptions).
# ponytail: slots are a JSON array, so deleting a tag leaves a recipe slot pointing at nothing
# (the recipe then fails validation on edit). Upgrade = a recipe_slots join table with a foreign key.
class Recipe < ApplicationRecord
  include GenerationOptions

  OUTPUT_COLLECTIONS = %w[photobank ready].freeze

  # Runs outlive their recipe.
  has_many :runs, class_name: "RecipeRun", dependent: :nullify
  has_many_attached :examples

  enum :kind, %w[image video].index_by(&:itself), validate: true

  normalizes :inputs, with: ->(inputs) do
    Array(inputs).filter_map { { "collection" => it["collection"].to_s, "tag_id" => it["tag_id"].to_i } if it["tag_id"].present? }
  end
  # The shot group its runs pick a shot from; nil takes no shot.
  normalizes :shot_group, with: ->(value) { value.strip.presence }

  validates :name, :body, :inputs, presence: true
  validates :output_collection, inclusion: { in: OUTPUT_COLLECTIONS }
  validate do
    errors.add(:inputs, "include an unknown folder") unless inputs.all? { it["collection"].in?(LibraryMedia.collections.keys) }
    errors.add(:inputs, "include an unknown tag") unless Tag.where(id: tag_ids).count == tag_ids.uniq.size
    errors.add(:inputs, "must be a single photo to make a video") if video? && inputs.size > 1
  end

  scope :ordered, -> { order(:name) }

  def tag_ids = inputs.map { it["tag_id"] }

  # [collection, tag] per slot; the tag is nil once deleted.
  def slots
    tags = Tag.where(id: tag_ids).index_by(&:id)
    inputs.map { [ it["collection"], tags[it["tag_id"]] ] }
  end

  # The index of the first slot the media fits, or nil.
  def slot_for(media) = inputs.index { it["collection"] == media.collection && it["tag_id"] == media.tag_id }

  def reads?(collection) = inputs.any? { it["collection"] == collection }

  # `media` fill the slots in order; `shot` is from the recipe's shot group; `options` override the recipe's.
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot doesn't fit or an option isn't available.
  def run!(media:, shot: nil, extra_prompt: nil, options: {})
    run = runs.new(shot:, extra_prompt:, inputs: media.each_with_index.map { |item, position| RecipeRunInput.new(library_media: item, position:) })
    # Set after the defaults fill in, so an unavailable pick fails validation instead of being dropped.
    run.options = run.options.merge(options.to_h.stringify_keys)
    run.start!
  end
end
