# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :user, inverse_of: :subscription

  validates :user_id, uniqueness: true
end
