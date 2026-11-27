# frozen_string_literal: true

class GuideRule < ApplicationRecord
  belongs_to :guide, inverse_of: :rules
  belongs_to :chapter, class_name: "GuideChapter", foreign_key: :guide_chapter_id, inverse_of: :rules

  validates :title, :number, :position, presence: true
  validates :number, uniqueness: { scope: :guide_id }

  before_validation :assign_guide_from_chapter, on: :create

  def label = "##{number}"

  private

  def assign_guide_from_chapter
    self.guide_id ||= chapter&.guide_id
  end
end
