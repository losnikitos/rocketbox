# frozen_string_literal: true

# A graph of media processing: input folders feed transformation steps, steps feed further steps or output folders.
# Nodes and edges are edited one at a time through nested attributes, so a workflow can be incomplete.
# Played from a start folder or media as one of its WorkflowRuns. With `autorun`, each media landing in a start folder
# starts a run of its own, picked for that folder (n8n's trigger node, passing on the new item).
class Workflow < ApplicationRecord
  has_many :nodes, -> { order(:id) }, class_name: "WorkflowNode", inverse_of: :workflow, dependent: :destroy
  has_many :edges, -> { order(:id) }, class_name: "WorkflowEdge", inverse_of: :workflow, dependent: :delete_all
  has_many :runs, -> { order(:id) }, class_name: "WorkflowRun", inverse_of: :workflow, dependent: :delete_all
  accepts_nested_attributes_for :nodes, :edges, allow_destroy: true

  validates :name, presence: true

  def latest_run = runs.last || runs.create!

  # Saved folders and media that feed steps and that nothing feeds.
  def start_nodes
    saved = edges.select(&:persisted?)
    nodes.select { |node| node.persisted? && !node.step? && saved.any? { it.from_id == node.id } && saved.none? { it.to_id == node.id } }
  end

  # Runs `media`, just landed in its folder, from each autorun workflow's start folders it fits, as its owner; never
  # through the workflow that made it.
  # ponytail: one run per media, and a loop across workflows (A feeds B feeds A) isn't caught.
  def self.autorun!(media)
    where(autorun: true).where.not(id: media.transformation_run&.workflow_run&.workflow_id).find_each do |workflow|
      workflow.start_nodes.select { it.folder_id == media.folder_id && (!it.tag_id || media.tag_ids.include?(it.tag_id)) }.each do |node|
        workflow.runs.create!(picks: { node.id.to_s => [ media.id ] }).start!(node, media.user)
      end
    end
  end
end
