class User < ApplicationRecord
  ROLES = %w[user admin].freeze

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  generates_token_for :whatsapp_login, expires_in: 1.hour do
    whatsapp_login_at
  end

  # Optional: OTP- and WhatsApp-created users have no password.
  has_secure_password validations: false
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true

  has_many :sessions, dependent: :destroy
  # smm_posts before library_media: post media items reference library media.
  has_many :smm_posts, dependent: :destroy
  has_many :library_media, dependent: :destroy
  has_many :incoming_messages, dependent: :destroy
  has_many :outgoing_messages, dependent: :destroy
  has_many :links, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_one :subscription, dependent: :destroy, inverse_of: :user
  has_one_attached :logo
  has_one_attached :instagram_avatar

  store_accessor :instagram_profile, :username, prefix: :instagram

  enum :brand_voice, %w[classic bold wild].index_by(&:itself), validate: { allow_nil: true }

  after_create :create_default_subscription

  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :role, inclusion: { in: ROLES }

  normalizes :email, with: -> { _1.strip.downcase.presence }
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

  # Copy, not share: the source blob is purged with its record (or on re-extraction).
  def copy_logo_from!(attachment)
    logo.attach(io: StringIO.new(attachment.download), filename: attachment.filename, content_type: attachment.content_type)
  end

  # Prefilled as START_<code> on /app/whatsapp; the sender's phone gets linked to this account.
  # Base58 × 8 ≈ 10^14 combinations; has_secure_token enforces a 24-char minimum.
  def regenerate_whatsapp_link_code
    update!(whatsapp_link_code: SecureRandom.base58(8))
  end

  def account_label
    business_name.presence || email.presence || name.presence || "+#{whatsapp_phone}"
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
