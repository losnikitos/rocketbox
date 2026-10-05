# frozen_string_literal: true

# How media is made from library media, one per input slot, plus example media.
# `inputs` lists the slots in order as { "collection", "tag_id" } and may repeat one (two staff photos).
# `kind` is how: one AI call making an image or a video, or a stitch of the inputs (photos or videos) into
# a video, 1 second each. Results land in `output_collection` with the first input's tag.
# `options` are the defaults for its AI runs (see GenerationOptions). Each run also picks a shot and a style if the recipe takes them.
# ponytail: slots are a JSON array, so deleting a tag leaves a recipe slot pointing at nothing
# (the recipe then fails validation on edit). Upgrade = a recipe_slots join table with a foreign key.
class Recipe < ApplicationRecord
  include GenerationOptions

  OUTPUT_COLLECTIONS = %w[photobank ready].freeze
  # Label and icon per kind.
  KINDS = { "generate_image" => [ "Gen image", "photo" ], "generate_video" => [ "Gen video", "film" ], "stitch" => [ "Stitch", "scissors" ] }.freeze

  # Runs outlive their recipe.
  has_many :runs, class_name: "RecipeRun", dependent: :nullify
  has_many_attached :examples

  enum :kind, KINDS.keys.index_by(&:itself), validate: true
  # A stitch has no prompt.
  attribute :body, default: ""

  normalizes :inputs, with: ->(inputs) do
    Array(inputs).filter_map { { "collection" => it["collection"].to_s, "tag_id" => it["tag_id"].to_i } if it["tag_id"].present? }
  end
  # The shot group its runs pick a shot from; nil takes no shot. `takes_style`: its runs pick a style.
  normalizes :shot_group, with: ->(value) { value.strip.presence }

  before_validation(if: :stitch?) { self.shot_group, self.takes_style = nil, false }
  validates :name, :inputs, presence: true
  validates :body, presence: true, unless: :stitch?
  validates :output_collection, inclusion: { in: OUTPUT_COLLECTIONS }
  validate do
    errors.add(:inputs, "include an unknown folder") unless inputs.all? { it["collection"].in?(LibraryMedia.collections.keys) }
    errors.add(:inputs, "include an unknown tag") unless Tag.where(id: tag_ids).count == tag_ids.uniq.size
    errors.add(:inputs, "must be a single photo to make a video") if video? && inputs.size > 1
  end

  scope :ordered, -> { order(:name) }

  def video? = generate_video?

  def takes?(media) = media.story_image? || (stitch? && media.video?)

  def tag_ids = inputs.map { it["tag_id"] }

  # [collection, tag] per slot; the tag is nil once deleted.
  def slots
    tags = Tag.where(id: tag_ids).index_by(&:id)
    inputs.map { [ it["collection"], tags[it["tag_id"]] ] }
  end

  # The index of the first slot the media fits, or nil.
  def slot_for(media) = inputs.index { it["collection"] == media.collection && it["tag_id"] == media.tag_id }

  # The index tab it's listed under: "collection/tag_id" when every slot reads the same folder and tag, else "multiple".
  def source = inputs.uniq.one? ? inputs.first.values_at("collection", "tag_id").join("/") : "multiple"

  def source_label
    return "Multiple inputs" if source == "multiple"
    collection, tag = slots.first
    "#{collection.humanize} · #{tag&.name || "Unknown"}"
  end

  # Groups of recipes sharing a source, by label with multiple inputs last.
  def self.by_source(recipes) = recipes.group_by(&:source).values.sort_by { [ it.first.source == "multiple" ? 1 : 0, it.first.source_label ] }

  # `media` fill the slots in order; `shot` is from the recipe's shot group; `style` if it takes one; `options` override the recipe's.
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot or style doesn't fit or an option isn't available.
  def run!(media:, shot: nil, style: nil, extra_prompt: nil, options: {})
    run = runs.new(shot:, style:, extra_prompt:, inputs: media.each_with_index.map { |item, position| RecipeRunInput.new(library_media: item, position:) })
    # Set after the defaults fill in, so an unavailable pick fails validation instead of being dropped.
    run.options = run.options.merge(options.to_h.stringify_keys)
    run.start!
  end
end
