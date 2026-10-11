# frozen_string_literal: true

# A reusable piece of prompt text (e.g. the "Empty Chair" scene), in a prompt folder. Shared, or its `user`'s when one
# of their step runs wrote it (an LLM step), so it only feeds their runs. Prompt folder nodes feed workflow steps.
class Prompt < ApplicationRecord
  belongs_to :folder
  belongs_to :user, optional: true
  # Step runs outlive their input prompts; only the input rows go.
  has_many :transformation_run_inputs, as: :item, dependent: :delete_all
  # The step run that wrote it. Later step runs reusing it share it (see WorkflowRun).
  has_one :transformation_run, -> { order(:id) }, as: :result
  has_many :transformation_runs, as: :result, dependent: :destroy
  has_many_attached :examples

  validates :name, presence: true
  # A user's prompt is written by their step run, blank until it's done.
  validates :body, presence: true, unless: :user_id?
  validate { errors.add(:folder, "must be a prompt folder") unless folder&.prompt? }

  # Seed order follows a working day.
  scope :ordered, -> { order(:id) }
  scope :written, -> { where.not(body: "") }

  def item_kind = :prompt
end
