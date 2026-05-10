# frozen_string_literal: true

class Book < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  has_many :chapters, -> { order(:position) }, dependent: :destroy, inverse_of: :book

  validates :title, presence: true
end
