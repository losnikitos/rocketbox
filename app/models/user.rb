class User < ApplicationRecord
  ROLES = %w[user admin].freeze

  has_secure_password

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt.last(10)
  end


  has_many :sessions, dependent: :destroy
  has_one :subscription, dependent: :destroy, inverse_of: :user

  after_create :create_default_subscription

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, allow_nil: true, length: { minimum: 12 }
  validates :role, inclusion: { in: ROLES }

  normalizes :email, with: -> { _1.strip.downcase }

  def admin?
    role == "admin"
  end

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end

  private

    def create_default_subscription
      create_subscription!(active: false)
    end
end
