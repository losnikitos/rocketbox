# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :user, inverse_of: :subscription

  validates :user_id, uniqueness: true

  # Mirrors https://docs.stripe.com/api/subscriptions/object#subscription_object-status
  def self.stripe_status_grants_access?(status)
    %w[active trialing].include?(status.to_s)
  end
end
