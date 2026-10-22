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

  has_one :chat, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :rubrics, dependent: :destroy
  has_many :library_media, dependent: :destroy
  has_many :jobs, dependent: :destroy
  has_many :incoming_messages, dependent: :destroy
  has_many :outgoing_messages, dependent: :destroy
  has_many :links, dependent: :destroy
  has_many :reviews, dependent: :destroy
  # The prompts their step runs wrote.
  has_many :prompts, dependent: :destroy
  has_many :services, dependent: :destroy
  has_one :subscription, dependent: :destroy, inverse_of: :user
  has_one_attached :instagram_avatar

  store_accessor :instagram_profile, :username, prefix: :instagram

  enum :brand_voice, %w[classic bold wild].index_by(&:itself), validate: { allow_nil: true }

  after_create :create_default_subscription

  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :role, inclusion: { in: ROLES }

  normalizes :email, with: -> { _1.strip.downcase.presence }
  normalizes :whatsapp_phone, with: ->(phone) { phone.to_s.gsub(/\D/, "").presence }

  # Last FreshaAvailability.fetch result, kept until the next fetch.
  def fresha_calendar = super&.deep_symbolize_keys

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

  # Newest media in photobank/logo — the account logo shown in the UI.
  def logo_media
    library_media.where(folder_id: Folder.logo.id).order(created_at: :desc).first
  end

  def logo? = logo_media&.file&.attached?

  # Prefilled as START_<code> on /app/whatsapp; the sender's phone gets linked to this account.
  # Base58 × 8 ≈ 10^14 combinations; has_secure_token enforces a 24-char minimum.
  def regenerate_whatsapp_link_code
    update!(whatsapp_link_code: SecureRandom.base58(8))
  end

  # The first inbound text is stored before the user exists, so match the phone too.
  # Admins also see this account's workflow runs, in the same order as AgentTranscript.
  def whatsapp_thread(admin: false)
    phone = whatsapp_phone
    incoming = IncomingMessage.where(channel: "whatsapp", user: self)
    outgoing = OutgoingMessage.where(channel: "whatsapp", user: self)
    if phone.present?
      incoming = incoming.or(IncomingMessage.where(channel: "whatsapp", sender: phone))
      outgoing = outgoing.or(OutgoingMessage.where(channel: "whatsapp", recipient: phone))
    end

    rows = incoming.with_attached_attachments.to_a + outgoing.to_a
    reactions, bubbles = rows.partition { |message| message.kind == "reaction" }
    grouped = reactions.group_by { |message| message.payload.is_a?(Hash) ? message.payload.dig("reaction", "message_id").presence : nil }
    grouped.delete(nil)
    if admin
      bubbles += WorkflowRun.played_by(self)
        .includes(:workflow, step_runs: { inputs: { item: :folder }, result: :folder }).to_a
      rank = { IncomingMessage => 0, WorkflowRun => 1, OutgoingMessage => 2 }
      bubbles.sort_by! { |record| [ record.created_at, rank.fetch(record.class), record.id ] }
    else
      bubbles.sort_by!(&:created_at)
    end
    [ bubbles, grouped ]
  end

  # Owner and admin each get their own stream: the admin paint includes run cards and admin menus.
  # "owner"/"admin": Turbo drops false from a stream name, so a boolean would not match the subscription.
  def broadcast_whatsapp_thread
    variants = [ [ admin?, admin? ? "admin" : "owner", self ] ]
    variants << [ true, "admin", User.find_by(role: "admin") ] unless admin?
    variants.each do |admin, stream, viewer|
      next unless viewer

      Current.set(account: self, session: ViewerSession.new(viewer)) do
        messages, reactions = whatsapp_thread(admin:)
        Turbo::StreamsChannel.broadcast_replace_to(
          [ self, :whatsapp, stream ],
          target: "whatsapp_messages",
          partial: "accounts/whatsapp/messages",
          locals: { messages:, reactions: }
        )
      end
    end
  end

  def account_label
    business_name.presence || email.presence || name.presence || "+#{whatsapp_phone}"
  end

  # Drops usage so a reviewer starts from a finished setup. The business brief and logo stay,
  # which is what makes RocketboxAgent call onboarding complete.
  def reset_activity!
    transaction do
      phone = whatsapp_phone
      incoming = IncomingMessage.where(user: self)
      outgoing = OutgoingMessage.where(user: self)
      if phone.present?
        incoming = incoming.or(IncomingMessage.where(channel: "whatsapp", sender: phone))
        outgoing = outgoing.or(OutgoingMessage.where(channel: "whatsapp", recipient: phone))
      end
      incoming.destroy_all
      outgoing.destroy_all

      # played_by looks through media and prompts, so capture runs before those go.
      run_ids = WorkflowRun.played_by(self).pluck(:id)
      doomed = library_media.where.not(folder_id: Folder.logo.id)
      # Null first: workflow_nodes.library_media_id cascade-deletes the node.
      WorkflowNode.where(library_media_id: doomed.select(:id)).update_all(library_media_id: nil)
      doomed.destroy_all
      prompts.destroy_all
      WorkflowRun.where(id: run_ids).find_each do |run|
        run.step_runs.destroy_all
        run.destroy!
      end
      jobs.destroy_all
      RubricPost.where(rubric_id: rubrics.select(:id)).delete_all

      resets = Accounts::OnboardingController::RESETS
      update!(
        resets.fetch("instagram").merge(resets.fetch("whatsapp")).merge(resets.fetch("telegram")).merge(whatsapp_login_at: nil)
      )
      chat&.destroy!
    end
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

    ViewerSession = Struct.new(:user)
    private_constant :ViewerSession

    def create_default_subscription
      create_subscription!(active: false)
    end
end
