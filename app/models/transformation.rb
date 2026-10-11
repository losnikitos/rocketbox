# frozen_string_literal: true

# How items are made from given items: a workflow step's processing, owned by its step.
# `kind` is how, the slug of its `type` (see Transformation::Type), fixed once created, which fixes its layer: a Generation is one AI call
# making an image or a video (or a prompt, LLM); an Overlay lays its layer, filled from its first layer step, over one photo or video, as the same; an Edit (e.g. SmartCrop) edits
# one photo or video, as the same, or as a video (Zoom); a Scripted type cuts the
# media (photos or videos) into a reel, its layer over the cuts filled from `layer_steps` (see Transformation::Scripted).
# `options` are the defaults for its AI runs, or its type's own (see GenerationOptions).
# Its type `takes` items of some kinds and `makes` one kind; besides them, an AI kind making media has a fixed `style`.
class Transformation < ApplicationRecord
  include GenerationOptions

  # Runs outlive their transformation.
  has_many :runs, class_name: "TransformationRun", dependent: :nullify
  has_many :workflow_nodes, dependent: :restrict_with_error
  belongs_to :style, optional: true

  delegate :ai?, :video?, :single?, :reel?, :inputs, :takes, :fits?, :picks?, :makes, :layer, :cover, to: :type, allow_nil: true
  # Only AI kinds have a prompt.
  attribute :body, default: ""

  # Blank values fall back to the layer's defaults; an all-blank step stays, keeping later steps on their cuts.
  normalizes :layer_steps, with: ->(steps) { Array(steps).map { it.to_h.compact_blank } }

  before_validation do
    self.style = nil unless styled?
    self.layer_steps = [] unless layer_steps?
  end
  validates :name, presence: true
  validates :kind, inclusion: { in: -> { Type.all.map(&:slug) } }
  # The type is picked once, on create.
  validate { errors.add(:kind, "can't be changed") if persisted? && kind_changed? }
  after_update { workflow_nodes.each(&:touch) }

  def type = Type.find(kind)

  # Whether its layer is filled from `layer_steps`; the review type fills it from a review.
  def layer_steps? = layer.present? && !takes.include?(:review)

  # Whether it takes a style: an AI kind making media.
  def styled? = ai? && makes == :media

  # "Generation · Image", or "Overlay · Fully booked".
  def type_label = type&.then { "#{it.group.label} · #{it.label}" }

  # "Grok Imagine Video · 9:16 · 720p · 8 s", or "Zoom in · 3 s"; the type label for a type without options.
  def options_label
    return type_label unless ai? || type&.options
    option_choices.keys.filter_map do |key|
      next if (value = options[key]).blank?
      case key
      when "model" then models.find { it.model_id == value }&.name || value
      when "duration" then "#{value} s"
      when "zoom" then "Zoom #{value}"
      when "look" then Transformation::ColorGrade::LOOKS[value]
      else value
      end
    end.join(" · ").presence || type_label
  end

  # `items` are the run's inputs, in order: its main items, then the prompt and review it picked. The result lands in
  # `folder` with `tags` (media). `workflow_run` and its step `workflow_node` the run it's a step run of, if any.
  # `user` owns the result.
  # Runs the transformation as it is in memory, unsaved edits included (see TransformationRun#start!).
  # Raises ActiveRecord::RecordInvalid when the items don't fit or an option isn't available.
  def run!(items:, folder:, user: items.first&.user, tags: [], workflow_run: nil, workflow_node: nil)
    runs.new(style:, workflow_run:, workflow_node:,
             inputs: items.each_with_index.map { |item, position| TransformationRunInput.new(item:, position:) })
      .start!(user, folder:, tags:)
  end
end
