class User < ApplicationRecord
  ROLES = %w[user admin].freeze

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  has_many :sessions, dependent: :destroy
  has_many :library_media, dependent: :nullify
  has_many :media_generations, dependent: :nullify
  has_many :smm_posts, dependent: :destroy
  has_many :links, dependent: :destroy
  has_one :subscription, dependent: :destroy, inverse_of: :user
  has_one_attached :logo
  has_one_attached :instagram_avatar

  store_accessor :instagram_profile, :username, prefix: :instagram

  after_create :create_default_subscription

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  normalizes :email, with: -> { _1.strip.downcase }
  normalizes :whatsapp_phone, with: ->(phone) { phone.to_s.gsub(/\D/, "").presence }

  def admin?
    role == "admin"
  end

  def instagram_authorized?
    instagram_user_id.present? && instagram_access_token.present?
  end

  # Signed CDN picture URLs expire, so the picture is stored as an attachment instead of in the profile.
  def refresh_instagram_profile!
    raise InstagramOauth::Error, "Authorize Instagram first." if instagram_access_token.blank?

    profile = InstagramOauth.profile(instagram_access_token)
    picture_url = profile.delete("profile_picture_url")
    update!(instagram_user_id: profile.fetch("user_id").to_s, instagram_profile: profile)

    picture = picture_url && InstagramOauth.picture(picture_url)
    picture ? instagram_avatar.attach(**picture, filename: "#{instagram_username}.jpg") : instagram_avatar.purge
  rescue KeyError => e
    raise InstagramOauth::Error, "Instagram did not return #{e.key}."
  end

  def account_label
    business_name.presence || email
  end

  def whatsapp_connect_code!
    update!(whatsapp_connect_code: SecureRandom.alphanumeric(10)) unless whatsapp_connect_code
    whatsapp_connect_code
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
