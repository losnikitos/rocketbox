# frozen_string_literal: true

# How media is made from library media, one per input slot, plus an example image.
# `inputs` lists the slots in order as { "folder_id" } and may repeat one (two staff photos).
# `kind` is how: one AI call making an image or a video, or a stitch of the inputs (photos or videos) into
# a video, cut by its `effect` (see EFFECTS). Results land in `output_folder`.
# `options` are the defaults for its AI runs (see GenerationOptions). Each run also picks a shot and a style if the recipe takes them.
# ponytail: slots are a JSON array, so deleting a folder leaves a recipe slot pointing at nothing
# (the recipe then fails validation on edit). Upgrade = a recipe_slots join table with a foreign key.
class Recipe < ApplicationRecord
  include GenerationOptions

  # Label and icon per kind.
  KINDS = { "generate_image" => [ "Gen image", "photo" ], "generate_video" => [ "Gen video", "film" ], "stitch" => [ "Stitch", "scissors" ] }.freeze
  # Label and description per stitch effect.
  EFFECTS = {
    "default" => [ "Default", "Each input plays for 1 second, in order." ],
    "doppler" => [ "Doppler", "Cuts on the beat of the Doppler track, a random input per cut, never the same one twice in a row." ]
  }.freeze

  # Runs outlive their recipe.
  has_many :runs, class_name: "RecipeRun", dependent: :nullify
  has_one_attached :example
  belongs_to :output_folder, class_name: "Folder"
  before_validation(on: :create) { self.output_folder ||= Folder.ready }

  enum :kind, KINDS.keys.index_by(&:itself), validate: true
  # A stitch has no prompt.
  attribute :body, default: ""

  normalizes :inputs, with: ->(inputs) do
    Array(inputs).filter_map { { "folder_id" => it["folder_id"].to_i } if it["folder_id"].present? }
  end
  # The shot group its runs pick a shot from; nil takes no shot. `takes_style`: its runs pick a style.
  normalizes :shot_group, with: ->(value) { value.strip.presence }
  # The free-text group it's listed under on the index; nil is ungrouped.
  normalizes :group, with: ->(value) { value.strip.presence }

  before_validation(if: :stitch?) { self.shot_group, self.takes_style = nil, false }
  validates :name, :inputs, presence: true
  validates :body, presence: true, unless: :stitch?
  validates :effect, inclusion: { in: EFFECTS.keys }
  validate do
    errors.add(:inputs, "include an unknown folder") unless Folder.where(id: folder_ids).count == folder_ids.uniq.size
    errors.add(:output_folder, "must be in Photobank") unless output_folder&.root&.slug == "photobank"
    errors.add(:inputs, "must be a single photo to make a video") if video? && inputs.size > 1
  end
  # A run of unsaved edits: its job reloads the recipe, so it would run the saved kind and effect.
  validate(on: :run) { errors.add(:base, "Save to change the type.") if kind_changed? || effect_changed? }

  scope :ordered, -> { order(:name) }

  def self.groups = where.not(group: nil).distinct.order(:group).pluck(:group)

  def video? = generate_video?

  def takes?(media) = media.story_image? || (stitch? && media.video?)

  def folder_ids = inputs.map { it["folder_id"] }

  # The folder per slot; nil once deleted.
  def slots
    folders = Folder.includes(:parent).where(id: folder_ids).index_by(&:id)
    folder_ids.map { folders[it] }
  end

  # The index of the first slot the media fits, or nil.
  def slot_for(media) = folder_ids.index(media.folder_id)

  # `media` fill the slots in order; `shot` is from the recipe's shot group; `style` if it takes one.
  # Runs the recipe as it is in memory, unsaved edits included (see RecipeRun#start!).
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot or style doesn't fit or an option isn't available.
  def run!(media:, shot: nil, style: nil)
    runs.new(shot:, style:, inputs: media.each_with_index.map { |item, position| RecipeRunInput.new(library_media: item, position:) }).start!
  end
end
