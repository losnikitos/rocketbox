# frozen_string_literal: true

class TelegramUpload < ApplicationRecord
  belongs_to :user, optional: true
  has_one_attached :file

  validates :telegram_file_id, :telegram_file_unique_id, :kind, presence: true
  validates :telegram_file_unique_id, uniqueness: true
end

