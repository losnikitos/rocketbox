# frozen_string_literal: true

class Guide < ApplicationRecord
  extend FriendlyId

  ACCESS = %w[free members].freeze

  friendly_id :title, use: %i[finders slugged]

  has_many :chapters, -> { order(:position) }, class_name: "GuideChapter", dependent: :destroy, inverse_of: :guide
  has_many :rules, -> { order(:number) }, class_name: "GuideRule", dependent: :destroy, inverse_of: :guide

  validates :title, presence: true
  validates :access, inclusion: { in: ACCESS }

  scope :published, -> { where(published: true) }

  def free? = access == "free"
  def members? = access == "members"

  # ponytail: always true until members gating ships — check Current.user / subscription here.
  def open? = true

  def first_chapter = chapters.first

  def access_label = free? ? "Free" : "Members"
end
