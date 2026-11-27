# frozen_string_literal: true

class GuideChapter < ApplicationRecord
  extend FriendlyId

  belongs_to :guide, inverse_of: :chapters
  has_many :rules, -> { order(:position) }, class_name: "GuideRule", dependent: :destroy, inverse_of: :chapter

  friendly_id :title, use: %i[slugged scoped], scope: :guide
  def should_generate_new_friendly_id? = slug.blank?

  validates :title, presence: true
  validates :position, presence: true
end
