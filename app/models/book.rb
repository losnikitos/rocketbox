# frozen_string_literal: true

class Book < ApplicationRecord
  has_many :chapters, -> { order(:position) }, dependent: :destroy, inverse_of: :book

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
end
