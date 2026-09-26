class User < ApplicationRecord
  ROLES = %w[user admin].freeze

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  has_many :sessions, dependent: :destroy
  has_many :library_media, dependent: :nullify
  has_many :media_generations, dependent: :nullify
  has_many :smm_posts, dependent: :destroy
  has_one :subscription, dependent: :destroy, inverse_of: :user

  after_create :create_default_subscription

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  normalizes :email, with: -> { _1.strip.downcase }
  normalizes :whatsapp_phone, with: ->(phone) { phone.to_s.gsub(/\D/, "").presence }

  def admin?
    role == "admin"
  end

  def self.find_or_create_from_login!(email)
    user = find_or_initialize_by(email: email)
    if user.new_record?
      user.verified = true
      user.save!
    elsif !user.verified?
      user.update!(verified: true)
    end
    user
  end

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  private

    def create_default_subscription
      create_subscription!(active: false)
    end
end
