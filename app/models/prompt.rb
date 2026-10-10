# frozen_string_literal: true

# A reusable prompt (e.g. the "Empty Chair" scene): its `body` is appended to a transformation's body when a run uses it.
# Transformations take a prompt `folder`; the concrete prompt is picked per run.
class Prompt < ApplicationRecord
  # Runs outlive their prompt.
  has_many :transformation_runs, dependent: :nullify
  has_many_attached :examples

  validates :name, :body, :folder, presence: true

  # Seed order follows a working day.
  scope :ordered, -> { order(:id) }

  def self.folders = distinct.order(:folder).pluck(:folder)
end
