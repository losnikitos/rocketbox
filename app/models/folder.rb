# frozen_string_literal: true

# Where library media lives; workflow folder nodes point at folders. Global, shared by every account.
# Top-level folders (inbox and photobank are seeded) hold subfolders one level below.
# The slug is set from the name once and survives renames, so URLs and lookups by slug stay put.
# ponytail: code looks up inbox and photobank (new media, onboarding), inbox/business-card, inbox/logo and inbox/interior
# (card extraction, WhatsApp onboarding) and photobank/ready (default step output) by slug, so deleting those rows breaks them.
# Upgrade = a locked flag on those rows.
class Folder < ApplicationRecord
  extend FriendlyId

  friendly_id :name, use: %i[slugged scoped], scope: :parent

  belongs_to :parent, class_name: "Folder", optional: true
  has_many :children, -> { order(:name) }, class_name: "Folder", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :library_media, dependent: :restrict_with_error
  has_many :workflow_nodes, dependent: :restrict_with_error

  enum :color, %w[sky emerald amber rose violet slate].index_by(&:itself), validate: true

  validates :name, presence: true
  validate { errors.add(:parent, "must be a top-level folder") if parent&.parent_id }
  before_validation(on: :create) { self.color = parent.color if parent && !color_changed? }

  scope :ordered, -> { order(:name) }
  scope :roots, -> { where(parent_id: nil) }

  def self.inbox = roots.find_by!(slug: "inbox")
  def self.photobank = roots.find_by!(slug: "photobank")
  # Where a step with no output folder lands its results.
  def self.ready = photobank.children.find_by!(slug: "ready")

  def root? = parent_id.nil?
  def root = parent || self
  def path = [ parent&.name, name ].compact.join(" / ")

  # Every folder media can be moved into, as [[root name, [[path, id], ...]], ...] for grouped selects.
  def self.grouped_options(roots: self.roots)
    roots.ordered.includes(:children)
      .map { |root| [ root.name, [ [ root.name, root.id ], *root.children.map { [ it.path, it.id ] } ] ] }
  end

  # Moves the media up to the parent first, so deleting a subfolder never loses media.
  def destroy_into_parent
    transaction do
      library_media.update_all(folder_id: parent_id) unless root?
      destroy || raise(ActiveRecord::Rollback)
    end
  end
end
