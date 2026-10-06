# frozen_string_literal: true

# How media is made from library media, one per input slot, plus an example image.
# `inputs` lists the slots in order as { "folder_id" } and may repeat one (two staff photos).
# `kind` is how: one AI call making an image or a video, a stitch of the inputs (photos or videos) into
# a video, cut by its `effect` (see EFFECTS), or a feature: its `layer` over one photo or video, as the same.
# Results land in `output_folder`.
# `options` are the defaults for its AI runs (see GenerationOptions).
# Inputs besides media: a fixed `style` and a `shot_group` its runs pick a shot from (AI kinds);
# a review its runs pick (`takes_review`) and a fixed `layer_slug` (features).
# ponytail: slots are a JSON array, so deleting a folder leaves a recipe slot pointing at nothing
# (the recipe then fails validation on edit). Upgrade = a recipe_slots join table with a foreign key.
class Recipe < ApplicationRecord
  extend FriendlyId
  include GenerationOptions

  # Set from the name once and survives renames.
  friendly_id :name, use: %i[slugged finders]

  # Label and icon per kind.
  KINDS = {
    "generate_image" => [ "Gen image", "photo" ], "generate_video" => [ "Gen video", "film" ],
    "stitch" => [ "Stitch", "scissors" ], "feature" => [ "Feature", "bolt" ]
  }.freeze
  # Label and description per stitch effect.
  EFFECTS = {
    "default" => [ "Default", "Each input plays for 1 second, in order." ],
    "doppler" => [ "Doppler", "Cuts on the beat of the Doppler track, a random input per cut, never the same one twice in a row." ]
  }.freeze

  # Runs outlive their recipe.
  has_many :runs, class_name: "RecipeRun", dependent: :nullify
  has_one_attached :example
  belongs_to :output_folder, class_name: "Folder"
  belongs_to :style, optional: true
  before_validation(on: :create) { self.output_folder ||= Folder.ready }

  enum :kind, KINDS.keys.index_by(&:itself), validate: true
  # Only AI kinds have a prompt.
  attribute :body, default: ""

  normalizes :inputs, with: ->(inputs) do
    Array(inputs).filter_map { { "folder_id" => it["folder_id"].to_i } if it["folder_id"].present? }
  end
  # nil takes no shot.
  normalizes :shot_group, :layer_slug, with: ->(value) { value.strip.presence }
  # The free-text group it's listed under on the index; nil is ungrouped.
  normalizes :group, with: ->(value) { value.strip.presence }

  before_validation do
    self.shot_group, self.style = nil, nil unless ai?
    self.takes_review, self.layer_slug = false, nil unless feature?
  end
  validates :name, presence: true
  validates :inputs, presence: true, unless: :generate_image?
  validates :body, presence: true, if: :ai?
  validates :effect, inclusion: { in: EFFECTS.keys }
  validates :layer_slug, inclusion: { in: Layer::ALL.map(&:slug) }, if: :feature?
  validate do
    errors.add(:inputs, "include an unknown folder") unless Folder.where(id: folder_ids).count == folder_ids.uniq.size
    errors.add(:output_folder, "must be in Photobank") unless output_folder&.root&.slug == "photobank"
    errors.add(:inputs, video? ? "must be a single photo to make a video" : "must be a single photo or video to make a story") if (video? || feature?) && inputs.size > 1
  end
  # A run of unsaved edits: its job reloads the recipe, so it would run the saved kind, effect and layer.
  validate(on: :run) { errors.add(:base, "Save to change the type or layer.") if kind_changed? || effect_changed? || layer_slug_changed? }

  scope :ordered, -> { order(:name) }

  def self.groups = where.not(group: nil).distinct.order(:group).pluck(:group)

  # A numeric slug would be found as an id.
  def normalize_friendly_id(text) = super.then { it.match?(/\A\d+\z/) ? "recipe-#{it}" : it }

  def ai? = generate_image? || generate_video?

  def video? = generate_video?

  def layer = (Layer.find(layer_slug) if layer_slug)

  def takes?(media) = media.story_image? || (!ai? && media.video?)

  def folder_ids = inputs.map { it["folder_id"] }

  # The folder per slot; nil once deleted.
  def slots
    folders = Folder.includes(:parent).where(id: folder_ids).index_by(&:id)
    folder_ids.map { folders[it] }
  end

  # The index of the first slot the media fits, or nil.
  def slot_for(media) = folder_ids.index(media.folder_id)

  # `media` fill the slots in order; `shot` is from the recipe's shot group, `review` for a feature that takes one.
  # `user` owns the result. Runs the recipe as it is in memory, unsaved edits included (see RecipeRun#start!).
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot or review doesn't fit or an option isn't available.
  def run!(media:, shot: nil, review: nil, user: media.first&.user)
    runs.new(shot:, style:, review:, inputs: media.each_with_index.map { |item, position| RecipeRunInput.new(library_media: item, position:) }).start!(user)
  end
end
