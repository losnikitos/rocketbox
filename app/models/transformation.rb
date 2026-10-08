# frozen_string_literal: true

# How media is made from given media: a recipe's processing step, and anything else that runs one.
# `kind` is how, the slug of its `type` (see Transformation::Type), fixed once created, which fixes its layer: a Generation is one AI call
# making an image or a video; an Overlay lays its layer over one photo or video, as the same; an Edit (e.g. SmartCrop) edits
# one photo or video, as the same; a Scripted type cuts the
# media (photos or videos) into a reel, its layer over the cuts filled from `layer_steps` (see Transformation::Scripted).
# `options` are the defaults for its AI runs (see GenerationOptions).
# Inputs besides media: a fixed `style` and a `shot_group` its runs pick a shot from (AI kinds); a review its runs
# pick (the review type).
# A recipe's is shared by the recipes pointing at it, so editing it changes them all; a workflow step owns its own.
class Transformation < ApplicationRecord
  include GenerationOptions

  # Runs outlive their transformation.
  has_many :runs, class_name: "TransformationRun", dependent: :nullify
  has_many :recipes, dependent: :restrict_with_error
  has_many :workflow_nodes, dependent: :restrict_with_error
  belongs_to :style, optional: true
  # Editing it edits its recipes, which the index lists recently edited first.
  after_update { recipes.touch_all }

  delegate :ai?, :video?, :single?, :reel?, :layer, :takes_review?, :cover, to: :type, allow_nil: true
  # Only AI kinds have a prompt.
  attribute :body, default: ""

  # Blank values fall back to the layer's defaults; an all-blank step stays, keeping later steps on their cuts.
  normalizes :layer_steps, with: ->(steps) { Array(steps).map { it.to_h.compact_blank } }
  # nil takes no shot.
  normalizes :shot_group, with: ->(value) { value.strip.presence }

  before_validation do
    self.shot_group, self.style = nil, nil unless ai?
    self.layer_steps = [] unless reel? && layer
  end
  validates :name, presence: true
  validates :kind, inclusion: { in: -> { Type.all.map(&:slug) } }
  # A workflow step's is made blank from its type; its runs need a prompt (see TransformationRun).
  validates :body, presence: true, if: :ai?, on: :update
  # The type is picked once, on create.
  validate { errors.add(:kind, "can't be changed") if persisted? && kind_changed? }
  # A run of unsaved edits: its job reloads the transformation, so it would run the saved layer steps.
  validate(on: :run) { errors.add(:base, "Save to change the layer steps.") if layer_steps_changed? }

  def type = Type.find(kind)

  # "Generation · Image", or "Overlay · Fully booked".
  def type_label = type&.then { "#{it.group.label} · #{it.label}" }

  def takes?(media) = media.story_image? || (!ai? && media.video?)

  # `media` are the run's source media, in order; the result lands in `folder` with `tags`. `shot` is from the shot
  # group, `review` for the review type, `recipe` the one it runs for, if any, or `workflow_run` and its step
  # `workflow_node`. `user` owns the result.
  # Runs the transformation as it is in memory, unsaved edits included (see TransformationRun#start!).
  # Raises ActiveRecord::RecordInvalid when the media, shot or review don't fit or an option isn't available.
  def run!(media:, folder:, user: media.first&.user, tags: [], shot: nil, review: nil, recipe: nil, workflow_run: nil, workflow_node: nil)
    runs.new(recipe:, shot:, style:, review:, workflow_run:, workflow_node:,
             inputs: media.each_with_index.map { |item, position| TransformationRunInput.new(library_media: item, position:) })
      .start!(user, folder:, tags:)
  end
end
