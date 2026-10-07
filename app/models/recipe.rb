# frozen_string_literal: true

# How media is made from library media, plus an example image.
# `inputs` lists the folders it takes media from in order as { "folder_id", "count" }, one per folder (two staff photos
# is one input with count 2). A run sees the picked media as one flat list.
# `kind` is how, the slug of its `type` (see RecipeType), which fixes its layer: a Generation is one AI call making an
# image or a video; an Overlay lays its layer over one photo or video, as the same; a Scripted type cuts the inputs
# (photos or videos) into a reel, its layer over the cuts filled from `layer_steps` (see RecipeType::Scripted).
# Results land in `output_folder`.
# `options` are the defaults for its AI runs (see GenerationOptions).
# Inputs besides media: a fixed `style` and a `shot_group` its runs pick a shot from (AI kinds); a review its runs
# pick (the review type).
# ponytail: slots are a JSON array, so deleting a folder leaves a recipe slot pointing at nothing
# (the recipe then fails validation on edit). Upgrade = a recipe_slots join table with a foreign key.
class Recipe < ApplicationRecord
  extend FriendlyId
  include GenerationOptions

  # Set from the name once and survives renames.
  friendly_id :name, use: %i[slugged finders]

  # Runs outlive their recipe.
  has_many :runs, class_name: "RecipeRun", dependent: :nullify
  has_one_attached :example
  belongs_to :output_folder, class_name: "Folder"
  belongs_to :style, optional: true
  # Where it's listed on the index and in the sidebar; nil is ungrouped.
  belongs_to :recipe_folder, optional: true
  before_validation(on: :create) { self.output_folder ||= Folder.ready }

  delegate :ai?, :video?, :overlay?, :reel?, :layer, :takes_review?, to: :type, allow_nil: true
  # Only AI kinds have a prompt.
  attribute :body, default: ""

  # Inputs from one folder merge, their counts summed.
  normalizes :inputs, with: ->(inputs) do
    Array(inputs).select { it["folder_id"].present? }.group_by { it["folder_id"].to_i }
      .map { |id, rows| { "folder_id" => id, "count" => rows.sum { [ it["count"].to_i, 1 ].max } } }
  end
  # Blank values fall back to the layer's defaults; an all-blank step is dropped.
  normalizes :layer_steps, with: ->(steps) { Array(steps).map { it.to_h.compact_blank }.reject(&:empty?) }
  # nil takes no shot.
  normalizes :shot_group, with: ->(value) { value.strip.presence }

  before_validation do
    self.shot_group, self.style = nil, nil unless ai?
    self.layer_steps = [] unless reel? && layer
  end
  validates :name, presence: true
  validates :kind, inclusion: { in: -> { RecipeType.all.map(&:slug) } }
  validates :inputs, presence: true
  validates :body, presence: true, if: :ai?
  validate do
    errors.add(:inputs, "include an unknown folder") unless Folder.where(id: folder_ids).count == folder_ids.uniq.size
    errors.add(:output_folder, "must be in Photobank") unless output_folder&.root&.slug == "photobank"
    errors.add(:inputs, video? ? "must be a single photo to make a video" : "must be a single photo or video to make a story") if (video? || overlay?) && media_count > 1
  end
  # A run of unsaved edits: its job reloads the recipe, so it would run the saved type and layer steps.
  validate(on: :run) { errors.add(:base, "Save to change the type.") if kind_changed? || layer_steps_changed? }

  scope :ordered, -> { order(:name) }

  # A numeric slug would be found as an id.
  def normalize_friendly_id(text) = super.then { it.match?(/\A\d+\z/) ? "recipe-#{it}" : it }

  def folder_name = recipe_folder&.name

  # Files it by folder name, a new one saved with the recipe; blank ungroups it.
  def folder_name=(name)
    self.recipe_folder = name.to_s.strip.presence&.then { RecipeFolder.find_or_initialize_by(name: it) }
  end

  def type = RecipeType.find(kind)

  # "Generation · Image", or "Overlay · Fully booked".
  def type_label = type&.then { "#{it.group.label} · #{it.label}" }

  def takes?(media) = media.story_image? || (!ai? && media.video?)

  def folder_ids = inputs.map { it["folder_id"] }

  # How many media a run takes, across inputs.
  def media_count = inputs.sum { it["count"] }

  # [folder, count] per input; the folder is nil once deleted.
  def slots
    folders = Folder.includes(:parent).where(id: folder_ids).index_by(&:id)
    inputs.map { [ folders[it["folder_id"]], it["count"] ] }
  end

  # `media` are the inputs' counts from their folders; `shot` is from the recipe's shot group, `review` for the review type.
  # `user` owns the result. Runs the recipe as it is in memory, unsaved edits included (see RecipeRun#start!).
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot or review doesn't fit or an option isn't available.
  def run!(media:, shot: nil, review: nil, user: media.first&.user)
    runs.new(shot:, style:, review:, inputs: media.each_with_index.map { |item, position| RecipeRunInput.new(library_media: item, position:) }).start!(user)
  end
end
