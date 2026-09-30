# frozen_string_literal: true

# How an SMM post is made: a Workflow class (app/workflows, shared by many recipes) plus this recipe's
# prompt for the AI steps, text for each text step, and example media.
class Recipe < ApplicationRecord
  AI_NODES = [ Workflow::AiImage, Workflow::AiVideo ].freeze

  has_many :smm_posts, dependent: :restrict_with_exception
  has_many :generations, dependent: :restrict_with_exception
  has_many_attached :examples

  attr_readonly :workflow

  # The library media this recipe suits.
  enum :media_type, LibraryMedia.media_types, validate: true

  before_validation { self.texts = texts.to_h.slice(*text_steps.map(&:key)) }

  validates :name, :prompt, presence: true
  validates :workflow, inclusion: { in: -> { Workflow.all.map(&:name) } }
  validate { errors.add(:texts, "can't be blank") if text_steps.any? { texts[it.key].blank? } }

  scope :ordered, -> { order(:name) }

  delegate :format, :input_count, to: :workflow_class, allow_nil: true

  def workflow_class
    Workflow.all.find { it.name == workflow }
  end

  def text_steps
    workflow_class&.text_steps.to_a
  end

  # The step's params with this recipe's prompt or text filled in.
  def params_for(step)
    return step.params.merge("prompt" => prompt) if step.node.in?(AI_NODES)
    return step.params.merge("body" => texts[step.key]) if step.node == Workflow::TextOverlay

    step.params
  end
end
