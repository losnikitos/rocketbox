# frozen_string_literal: true

class Chapter < ApplicationRecord
  belongs_to :book, inverse_of: :chapters

  has_many_attached :embedded_images

  scope :free, -> { where(free: true) }

  validates :title, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :book_id }

  before_validation :localize_notion_images_in_body, if: :will_save_change_to_body?

  private

    def localize_notion_images_in_body
      self.body = Notion::ImageLocalizer.call(record: self, text: body)
    end
end
