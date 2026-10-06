# frozen_string_literal: true

# How media is made from library media, one per input slot, plus an example image.
# `inputs` lists the slots in order as { "folder_id" } and may repeat one (two staff photos).
# `kind` is how: one AI call making an image or a video, or scripted, no AI, by its `effect` (see EFFECTS), which fixes
# its layer: an overlay effect lays it over one photo or video, as the same; a reel effect cuts the inputs (photos or
# videos) into a video, its layer over its first cuts, one per `layer_steps` entry, each filled from its entry (see RecipeRun#reel).
# Results land in `output_folder`.
# `options` are the defaults for its AI runs (see GenerationOptions).
# Inputs besides media: a fixed `style` and a `shot_group` its runs pick a shot from (AI kinds); a review its runs
# pick (the review effect).
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
    "scripted" => [ "Scripted", "bolt" ]
  }.freeze
  # Label, layer slug (nil for none) and description per scripted effect.
  EFFECTS = {
    "fully-booked" => [ "Fully booked", "fully-booked-color", "Fully booked for the day, over one photo or video." ],
    "daily" => [ "Daily", "daily", "The time and a caption, over one photo or video." ],
    "review" => [ "Review", "review", "A 5-star review, over one photo or video." ],
    "calendar" => [ "Calendar", "calendar", "Free slots for the next three days, over one photo or video." ],
    "steps" => [ "Steps", nil, "Each input plays for 1 second, in order." ],
    "doppler" => [ "Doppler", nil, "Cuts on the beat of the Doppler track, a random input per cut, never the same one twice in a row." ],
    "welcome" => [ "Welcome", "welcome", "Cuts where the Welcome reel cuts, under its track, a random input per cut, never the same one twice in a row." ],
    # Instagram's own copy of the track: https://www.instagram.com/reels/audio/27554386410835342/
    # The Graph API can't attach library audio to a reel, so the track is baked into the video.
    "black-eyed-peas" => [ "Black Eyed Peas", "caption", "Cuts every bar of its track, five cuts, a random input per cut, never the same one twice in a row." ]
  }.freeze
  # The effects laying their layer over one photo or video; the rest cut their inputs into a reel.
  OVERLAYS = %w[fully-booked daily review calendar].freeze

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
  # Blank values fall back to the layer's defaults; an all-blank step is dropped.
  normalizes :layer_steps, with: ->(steps) { Array(steps).map { it.to_h.compact_blank }.reject(&:empty?) }
  # nil takes no shot.
  normalizes :shot_group, with: ->(value) { value.strip.presence }
  # The free-text group it's listed under on the index; nil is ungrouped.
  normalizes :group, with: ->(value) { value.strip.presence }

  before_validation do
    self.shot_group, self.style = nil, nil unless ai?
    self.effect = nil unless scripted?
    self.layer_steps = [] unless reel? && layer
  end
  validates :name, presence: true
  validates :inputs, presence: true, unless: :generate_image?
  validates :body, presence: true, if: :ai?
  validates :effect, inclusion: { in: EFFECTS.keys }, if: :scripted?
  validate do
    errors.add(:inputs, "include an unknown folder") unless Folder.where(id: folder_ids).count == folder_ids.uniq.size
    errors.add(:output_folder, "must be in Photobank") unless output_folder&.root&.slug == "photobank"
    errors.add(:inputs, video? ? "must be a single photo to make a video" : "must be a single photo or video to make a story") if (video? || overlay?) && inputs.size > 1
  end
  # A run of unsaved edits: its job reloads the recipe, so it would run the saved kind, effect and layer steps.
  validate(on: :run) { errors.add(:base, "Save to change the type or effect.") if kind_changed? || effect_changed? || layer_steps_changed? }

  scope :ordered, -> { order(:name) }

  def self.groups = where.not(group: nil).distinct.order(:group).pluck(:group)

  # A numeric slug would be found as an id.
  def normalize_friendly_id(text) = super.then { it.match?(/\A\d+\z/) ? "recipe-#{it}" : it }

  def ai? = generate_image? || generate_video?

  def video? = generate_video?

  def overlay? = scripted? && effect.in?(OVERLAYS)

  def reel? = scripted? && !overlay?

  def layer = (EFFECTS.dig(effect, 1)&.then { Layer.find(it) } if scripted?)

  def takes_review? = scripted? && effect == "review"

  # "Gen image", or "Scripted · Fully booked".
  def type_label = [ KINDS[kind].first, EFFECTS.dig(effect, 0) ].compact.join(" · ")

  def takes?(media) = media.story_image? || (!ai? && media.video?)

  def folder_ids = inputs.map { it["folder_id"] }

  # The folder per slot; nil once deleted.
  def slots
    folders = Folder.includes(:parent).where(id: folder_ids).index_by(&:id)
    folder_ids.map { folders[it] }
  end

  # The index of the first slot the media fits, or nil.
  def slot_for(media) = folder_ids.index(media.folder_id)

  # `media` fill the slots in order; `shot` is from the recipe's shot group, `review` for the review effect.
  # `user` owns the result. Runs the recipe as it is in memory, unsaved edits included (see RecipeRun#start!).
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot or review doesn't fit or an option isn't available.
  def run!(media:, shot: nil, review: nil, user: media.first&.user)
    runs.new(shot:, style:, review:, inputs: media.each_with_index.map { |item, position| RecipeRunInput.new(library_media: item, position:) }).start!(user)
  end
end
