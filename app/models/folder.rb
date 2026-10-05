# frozen_string_literal: true

# Where library media lives; recipe inputs and outputs point at folders. Global, shared by every account.
# The roots (inbox, photobank) are fixed; subfolders sit one level below a root.
# The slug is set from the name once and survives renames, so URLs and lookups by slug stay put.
# ponytail: code looks up inbox/business-card, inbox/logo and inbox/interior by slug (card extraction, WhatsApp onboarding)
# and photobank/ready (recipe output, features), so deleting those rows breaks them. Upgrade = a locked flag on those rows.
class Folder < ApplicationRecord
  extend FriendlyId

  ROOTS = %w[inbox photobank].freeze

  friendly_id :name, use: %i[slugged scoped], scope: :parent

  belongs_to :parent, class_name: "Folder", optional: true
  has_many :children, -> { order(:name) }, class_name: "Folder", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :library_media, dependent: :restrict_with_error
  has_many :output_recipes, class_name: "Recipe", foreign_key: :output_folder_id, inverse_of: :output_folder, dependent: :restrict_with_error

  validates :name, presence: true
  validate { errors.add(:parent, "must be a top-level folder") if parent&.parent_id }
  validate(on: :update) { errors.add(:base, "Top-level folders can't be changed.") if root? && changed? }
  before_destroy { throw :abort if root? }

  scope :ordered, -> { order(:name) }
  scope :roots, -> { where(parent_id: nil) }

  ROOTS.each { |slug| define_singleton_method(slug) { roots.find_by!(slug:) } }
  # Final recipe output.
  def self.ready = photobank.children.find_by!(slug: "ready")

  def root? = parent_id.nil?
  def root = parent || self
  def path = [ parent&.name, name ].compact.join(" / ")

  # Every folder media can be moved into, as [[root name, [[path, id], ...]], ...] for grouped selects.
  def self.grouped_options(roots: ROOTS)
    where(slug: roots, parent_id: nil).includes(:children).sort_by { roots.index(it.slug) }
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
