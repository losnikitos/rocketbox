# frozen_string_literal: true

# Library media in, a transformation, media out; plus an example image.
# `inputs` lists the folders it takes media from in order as { "folder_id", "tag_id", "count" }, one per folder and tag
# (two staff photos is one input with count 2); a blank tag takes any media in the folder. A run sees the picked media
# as one flat list.
# `transformation` is how its media is made (see Transformation), edited with the recipe.
# Results land in `output_folder`, tagged with `output_tag_ids`.
# ponytail: slots and output tags are JSON arrays, so deleting a folder or tag leaves the recipe pointing at nothing
# (the recipe then fails validation on edit). Upgrade = recipe_slots and recipe_output_tags join tables with foreign keys.
class Recipe < ApplicationRecord
  extend FriendlyId

  # Follows the name; old slugs still find it, so an open page keeps working after a rename.
  friendly_id :name, use: %i[slugged finders history]

  # Runs outlive their recipe.
  has_many :runs, class_name: "TransformationRun", dependent: :nullify
  has_one_attached :example
  belongs_to :transformation
  accepts_nested_attributes_for :transformation, update_only: true
  belongs_to :output_folder, class_name: "Folder"
  # Where it's listed on the index and in the sidebar; nil is ungrouped.
  belongs_to :recipe_folder, optional: true
  # After the given attributes, so a nested transformation fills its options for its own kind.
  after_initialize(if: :new_record?) { build_transformation unless transformation }
  before_validation(on: :create) { self.output_folder ||= Folder.ready }
  # The recipe form doesn't name its transformation.
  before_validation { transformation.name = name if transformation.name.blank? }

  delegate :ai?, :video?, :overlay?, :reel?, :layer, :takes_review?, :type, :type_label, :takes?, :style, :shot_group, to: :transformation

  # Inputs from one folder with one tag merge, their counts summed.
  normalizes :inputs, with: ->(inputs) do
    Array(inputs).select { it["folder_id"].present? }.group_by { [ it["folder_id"].to_i, it["tag_id"].presence&.to_i ] }
      .map { |(folder_id, tag_id), rows| { "folder_id" => folder_id, "tag_id" => tag_id, "count" => rows.sum { [ it["count"].to_i, 1 ].max } }.compact }
  end
  normalizes :output_tag_ids, with: ->(ids) { Array(ids).compact_blank.map(&:to_i).uniq }

  validates :name, presence: true
  validates :inputs, presence: true
  validate do
    errors.add(:inputs, "include an unknown folder") unless Folder.where(id: folder_ids).count == folder_ids.uniq.size
    tag_ids = inputs.filter_map { it["tag_id"] }.uniq
    errors.add(:inputs, "include an unknown tag") unless Tag.where(id: tag_ids).count == tag_ids.size
    errors.add(:output_tag_ids, "include an unknown tag") unless Tag.where(id: output_tag_ids).count == output_tag_ids.size
    errors.add(:output_folder, "must be in Photobank") unless output_folder&.root&.slug == "photobank"
    errors.add(:inputs, video? ? "must be a single photo to make a video" : "must be a single photo or video to make a story") if (video? || overlay?) && media_count > 1
  end

  scope :ordered, -> { order(:name) }

  # A numeric slug would be found as an id.
  def normalize_friendly_id(text) = super.then { it.match?(/\A\d+\z/) ? "recipe-#{it}" : it }

  def should_generate_new_friendly_id? = name_changed? || super

  def folder_name = recipe_folder&.name

  # Files it by folder name, a new one saved with the recipe; blank ungroups it.
  def folder_name=(name)
    self.recipe_folder = name.to_s.strip.presence&.then { RecipeFolder.find_or_initialize_by(name: it) }
  end

  def folder_ids = inputs.map { it["folder_id"] }

  def output_tags = Tag.where(id: output_tag_ids).ordered

  # How many media a run takes, across inputs.
  def media_count = inputs.sum { it["count"] }

  # [folder, tag, count] per input; the tag is nil for any media, the folder and tag nil once deleted.
  def slots
    folders = Folder.includes(:parent).where(id: folder_ids).index_by(&:id)
    tags = Tag.where(id: inputs.filter_map { it["tag_id"] }).index_by(&:id)
    inputs.map { [ folders[it["folder_id"]], tags[it["tag_id"]], it["count"] ] }
  end

  # Whether `media` can fill this input: it's in the input's folder and, if the input has a tag, has it.
  def self.takes_input?(input, media) = media.folder_id == input["folder_id"] && (input["tag_id"].nil? || media.tag_ids.include?(input["tag_id"]))

  # Whether `media`, in any order, fill every input's count exactly.
  # ponytail: greedy, tagged inputs first, so it can reject a valid pick when two tagged inputs share a folder and
  # one media has both tags. Upgrade = bipartite matching.
  def fills_inputs?(media)
    left = media.dup
    inputs.sort_by { it["tag_id"] ? 0 : 1 }.all? do |input|
      input["count"].times.all? { (index = left.index { self.class.takes_input?(input, it) }) && left.delete_at(index) }
    end && left.empty?
  end

  # `media` are the inputs' counts from their folders; `shot` is from the shot group, `review` for the review type.
  # `user` owns the result. Runs the recipe as it is in memory, unsaved edits included.
  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot or review doesn't fit or an option isn't available.
  def run!(media:, shot: nil, review: nil, user: media.first&.user)
    transformation.run!(media:, shot:, review:, user:, folder: output_folder, tags: output_tags.to_a, recipe: self)
  end
end
