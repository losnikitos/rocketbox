# frozen_string_literal: true

class SubscriptionRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def email=(value)
    super(value.to_s.strip.downcase.presence)
  end
end
