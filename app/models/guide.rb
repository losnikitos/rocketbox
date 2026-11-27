# frozen_string_literal: true

class Guide < ApplicationRecord
  extend FriendlyId

  friendly_id :title, use: %i[finders slugged]

  has_many :chapters, -> { order(:position) }, class_name: "GuideChapter", dependent: :destroy, inverse_of: :guide
  has_many :rules, -> { order(:number) }, class_name: "GuideRule", dependent: :destroy, inverse_of: :guide

  validates :title, presence: true

  scope :published, -> { where(published: true) }
end
