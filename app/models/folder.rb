# frozen_string_literal: true

# Where items live; workflow folder nodes point at folders. Global, shared by every account.
# Its `kind` says which items it holds: media (inbox and photobank are seeded), prompts or reviews; a subfolder takes
# its parent's. Top-level folders hold subfolders one level below, except Reviews, which holds every review.
# The slug is set from the name once and survives renames, so URLs and lookups by slug stay put.
# Top-level folders never move, so code looks up inbox, photobank, ready, prompts and reviews by slug.
# ponytail: code also looks up inbox/business-card, inbox/logo and inbox/interior (card extraction, WhatsApp
# onboarding) by slug, so moving or deleting those rows breaks them. Upgrade = a locked flag on those rows.
class Folder < ApplicationRecord
  extend FriendlyId

  friendly_id :name, use: %i[slugged scoped], scope: :parent
  def should_generate_new_friendly_id? = slug.blank?

  belongs_to :parent, class_name: "Folder", optional: true
  has_many :children, -> { order(:name) }, class_name: "Folder", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :library_media, dependent: :restrict_with_error
  has_many :prompts, dependent: :restrict_with_error
  has_many :reviews, dependent: :restrict_with_error
  has_many :workflow_nodes, dependent: :restrict_with_error
  has_many :rubrics, dependent: :restrict_with_error

  enum :color, %w[sky emerald amber red rose violet slate].index_by(&:itself), validate: true
  enum :kind, %w[media prompt review].index_by(&:itself), validate: true

  validates :name, presence: true
  validate { errors.add(:parent, "must be a top-level folder") if parent&.parent_id }
  validate { errors.add(:base, "Top-level folders stay top-level") if persisted? && parent_id_changed? && parent_id_was.nil? }
  validate { errors.add(:parent, "holds every review itself") if parent&.review? }
  validate { errors.add(:parent, "holds #{parent.kind.pluralize}") if parent && parent.kind != kind }
  validate { errors.add(:base, "#{parent.name} already has a folder named #{name}") if parent && parent_id_changed? && Folder.exists?(parent_id:, slug:) }
  before_validation(on: :create) do
    self.color = parent.color if parent && !color_changed?
    self.kind = parent.kind if parent
  end

  scope :ordered, -> { order(:name) }
  scope :roots, -> { where(parent_id: nil) }

  def self.inbox = roots.find_by!(slug: "inbox")
  def self.photobank = roots.find_by!(slug: "photobank")
  def self.prompts = roots.find_by!(slug: "prompts")
  def self.reviews = roots.find_by!(slug: "reviews")
  # Where a step with no output folder lands its results of `kind`.
  def self.ready(kind = "media") = kind.to_s == "prompt" ? prompts : roots.find_by!(slug: "ready")

  def root? = parent_id.nil?
  def root = parent || self
  def path = [ parent&.name, name ].compact.join(" / ")
  # Its id and its subfolders' ids: what a workflow node on it reads from.
  def tree_ids = @tree_ids ||= [ id, *children.ids ]

  # Its items: media, prompts or reviews.
  def items = { "media" => library_media, "prompt" => prompts, "review" => reviews }.fetch(kind)

  # Every media folder media can be moved into, as [[root name, [[path, id], ...]], ...] for grouped selects.
  def self.grouped_options(roots: self.roots.media)
    roots.ordered.includes(:children)
      .map { |root| [ root.name, [ [ root.name, root.id ], *root.children.map { [ it.path, it.id ] } ] ] }
  end

  # Moves the items up to the parent first, so deleting a subfolder never loses them.
  def destroy_into_parent
    transaction do
      items.update_all(folder_id: parent_id) unless root?
      destroy || raise(ActiveRecord::Rollback)
    end
  end
end
