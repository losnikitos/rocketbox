# frozen_string_literal: true

# A piece of work for one customer, e.g. two photos of the same haircut. The account's own, like its media.
# Shown as "@slug"; the slug is set from the name once and survives renames.
class Job < ApplicationRecord
  belongs_to :user
  has_many :library_media, dependent: :nullify

  # ponytail: one query per taken number; fine for dozens of jobs, a per-account counter column once there are thousands.
  before_validation(on: :create) do
    self.name = "Job #{(1..).find { |n| !user.jobs.exists?(slug: "job_#{n}") }}" if name.blank? && user
    self.slug = name&.parameterize(separator: "_") if slug.blank?
  end

  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(:created_at, :id) }

  # Moves the others' media into the oldest and deletes the others; returns the one kept.
  def self.merge!(jobs)
    keep, *rest = jobs.sort_by { [ it.created_at, it.id ] }
    transaction do
      LibraryMedia.where(job: rest).update_all(job_id: keep.id)
      rest.each(&:destroy!)
    end
    keep
  end
end
