# frozen_string_literal: true

# A scene to shoot (e.g. "Empty Chair"): its `body` is appended to a transformation's body when a run uses it.
# Transformations take a shot `group`; the concrete shot is picked per run.
class Shot < ApplicationRecord
  # Runs outlive their shot.
  has_many :transformation_runs, dependent: :nullify
  has_many_attached :examples

  validates :name, :body, :group, presence: true

  # Seed order follows a working day.
  scope :ordered, -> { order(:id) }

  def self.groups = distinct.order(:group).pluck(:group)
end
