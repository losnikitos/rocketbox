# frozen_string_literal: true

# How an SMM post is made: exactly one Workflow class (app/workflows) plus example media.
class Recipe < ApplicationRecord
  has_many :smm_posts, dependent: :restrict_with_exception
  has_many_attached :examples

  attr_readonly :workflow

  validates :name, presence: true
  validates :workflow, inclusion: { in: -> { Workflow.all.map(&:name) } }, uniqueness: true

  scope :ordered, -> { order(:name) }

  delegate :format, :input_count, to: :workflow_class, allow_nil: true

  def self.free_workflows
    Workflow.all.map(&:name) - pluck(:workflow)
  end

  def workflow_class
    Workflow.all.find { it.name == workflow }
  end
end
