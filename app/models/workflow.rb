# frozen_string_literal: true

# A graph of media processing: input folders feed transformation steps, steps feed further steps or output folders.
# Nodes and edges are edited one at a time through nested attributes, so a workflow can be incomplete.
# Played from a start folder or media as a WorkflowRun; for now only its draft.
class Workflow < ApplicationRecord
  has_many :nodes, -> { order(:id) }, class_name: "WorkflowNode", inverse_of: :workflow, dependent: :destroy
  has_many :edges, -> { order(:id) }, class_name: "WorkflowEdge", inverse_of: :workflow, dependent: :delete_all
  has_many :runs, -> { order(:id) }, class_name: "WorkflowRun", inverse_of: :workflow, dependent: :delete_all
  accepts_nested_attributes_for :nodes, :edges, allow_destroy: true

  validates :name, presence: true

  def draft_run = runs.first_or_create!
end
