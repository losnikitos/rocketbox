# frozen_string_literal: true

# What a library media shows; recipes are picked by it. Editable in admin.
# The slug is set from the name once and survives renames.
# ponytail: code looks up business-card, logo and interior by slug (card extraction, WhatsApp onboarding),
# so deleting those rows breaks onboarding. Upgrade = a locked flag on those rows.
class MediaType < ApplicationRecord
  extend FriendlyId

  friendly_id :name, use: :slugged

  has_many :library_media, dependent: :nullify
  has_many :recipes, dependent: :restrict_with_error

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
