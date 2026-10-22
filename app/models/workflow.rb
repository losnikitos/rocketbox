# frozen_string_literal: true

# A graph of media processing: input folders feed transformation steps, steps feed further steps or output folders.
# Nodes and edges are edited one at a time through nested attributes, so a workflow can be incomplete.
# Played from a start folder or media as one of its WorkflowRuns. With `autorun`, each media landing in a start folder
# starts a run of its own, picked for that folder (n8n's trigger node, passing on the new item).
# Built-in workflows (seeded by Workflow::*::ensure!) can't be renamed or deleted; the sidebar shows a pin.
class Workflow < ApplicationRecord
  extend FriendlyId

  # Seeded by Workflow::InboxSort / Workflow::BusinessCard / Workflow::HaircutReel (their NAME.parameterize).
  BUILT_IN_SLUGS = %w[inbox-sort business-card haircut-reel].freeze

  # Built-ins first (sidebar pin), then recently edited.
  scope :sidebar, -> {
    built_ins_first = Arel::Nodes::Case.new.when(arel_table[:slug].in(BUILT_IN_SLUGS)).then(0).else(1)
    order(built_ins_first, updated_at: :desc)
  }

  # Follows the name; old slugs still find it, so an open page keeps working after a rename.
  friendly_id :name, use: %i[slugged finders history]

  has_many :nodes, -> { order(:id) }, class_name: "WorkflowNode", inverse_of: :workflow, dependent: :destroy
  has_many :edges, -> { order(:id) }, class_name: "WorkflowEdge", inverse_of: :workflow, dependent: :delete_all
  has_many :runs, -> { order(:id) }, class_name: "WorkflowRun", inverse_of: :workflow, dependent: :delete_all
  accepts_nested_attributes_for :nodes, :edges, allow_destroy: true

  validates :name, presence: true
  validate :name_locked_when_built_in, on: :update
  before_destroy :prevent_built_in_destroy

  # Use the persisted slug — FriendlyId may already have rewritten `slug` in memory on rename.
  def built_in? = BUILT_IN_SLUGS.include?(slug_in_database || slug)

  # A numeric slug would be found as an id.
  def normalize_friendly_id(text) = super.then { it.match?(/\A\d+\z/) ? "workflow-#{it}" : it }

  def should_generate_new_friendly_id? = name_changed? || super

  def latest_run = runs.last || runs.create!

  # Saved folders and media that feed steps and that nothing feeds, and steps nothing feeds that take nothing they
  # aren't given (an LLM writing from its instruction alone).
  def start_nodes
    saved = edges.select(&:persisted?)
    nodes.select do |node|
      node.persisted? && saved.none? { it.to_id == node.id } &&
        (node.step? ? node.transformation.inputs.values.all? { it.begin.zero? } : saved.any? { it.from_id == node.id })
    end
  end

  # The start folders `media` fits (see WorkflowNode#takes?), as [[workflow, node], ...].
  def self.starts_for(media)
    includes(:nodes, :edges).order(:name).flat_map { |workflow| workflow.start_nodes.select { it.takes?(media) }.map { [ workflow, it ] } }
  end

  # Runs `media`, just landed in its folder, from each autorun workflow's start folders it fits, as its owner; never
  # through the workflow that made it. A waiting Collect for this user and folder takes the photo into that run
  # instead. Serialized per user so two photos arriving together can't both open a run.
  # ponytail: a loop across workflows (A feeds B feeds A) isn't caught.
  def self.autorun!(media)
    start = -> {
      joined = media.user && TransformationRun.open_collect_for(media)&.accept_media!(media)
      unless joined
        where(autorun: true).where.not(id: media.transformation_run&.workflow_run&.workflow_id).starts_for(media).each do |workflow, node|
          workflow.start_with!(node, media, media.user)
        end
      end
    }
    media.user ? media.user.with_lock(&start) : start.call
  end

  # A new run of `media` alone from start folder `node`, as `user`.
  def start_with!(node, media, user) = runs.create!(picks: { node.id.to_s => [ media.id ] }).tap { it.start!(node, user) }

  private

    def name_locked_when_built_in
      errors.add(:name, "can't be changed on a built-in workflow") if name_changed? && built_in?
    end

    def prevent_built_in_destroy
      return unless built_in?

      errors.add(:base, "Can't delete a built-in workflow")
      throw :abort
    end
end
