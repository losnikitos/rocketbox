# frozen_string_literal: true

class LibraryMedia < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :media_type, optional: true
  # Posts outlive their source media; only the join rows go.
  has_many :smm_post_media_items, dependent: :delete_all
  # Generated media outlive their source; only the generation rows go.
  has_many :generations, foreign_key: :source_media_id, inverse_of: :source_media, dependent: :destroy
  has_many :generated_media, through: :generations
  has_one :origin, class_name: "Generation", foreign_key: :generated_media_id, inverse_of: :generated_media, dependent: :destroy
  has_one :source_media, through: :origin
  has_one :recipe_run, foreign_key: :generated_media_id, inverse_of: :generated_media, dependent: :destroy
  has_one_attached :file
  has_one_attached :extracted_logo

  # Extracted business-card field => User column.
  CARD_FIELDS = {
    "business_name" => :business_name,
    "phone" => :phone,
    "person_name" => :name,
    "address" => :address,
    "website" => :homepage_url,
    "business_description" => :business_description
  }.freeze

  # Inbox: everything the owner sends or uploads. Photobank: curated media, manual upload only.
  # Ready: recipe output.
  enum :collection, %w[inbox photobank ready].index_by(&:itself), default: "inbox", validate: true

  validates :kind, presence: true
  validates :media_type, presence: true, if: :media_type_id
  validates :telegram_file_unique_id, uniqueness: true, allow_nil: true
  validates :whatsapp_media_id, uniqueness: true, allow_nil: true

  def business_card? = media_type&.slug == "business-card"

  # The Generation or RecipeRun that made this media; both have a status and an error.
  def maker = origin || recipe_run

  def story_image?
    return false unless file.attached?

    file.content_type.to_s.start_with?("image/") || kind.in?(%w[photo sticker])
  end

  # Prompts that suit this media.
  def prompts
    return [] unless story_image? && media_type

    Prompt.where(media_type:).with_attached_examples.ordered
  end

  def extraction_status
    extracted_info&.dig("status")
  end

  def extracted_account_attributes
    fields = extracted_info&.dig("fields") || {}
    CARD_FIELDS.to_h { |key, column| [ column, fields[key].to_s.strip ] }.compact_blank
  end

  def apply_extraction_to!(user)
    user.update!(extracted_account_attributes)
    user.copy_logo_from!(extracted_logo) if extracted_logo.attached?
  end

  # Call on an association (user.library_media.import_url!) so the lookup and the new record are scoped to that user.
  def self.import_url!(url)
    find_by(source_url: url) || begin
      io = RemoteFile.fetch(url)
      kind = kind_for(io.content_type)
      raise RemoteFile::Error, "#{io.content_type} is not a photo or video." unless kind.in?(%w[photo video])

      create!(kind: kind, source_url: url, file: { io: io, filename: RemoteFile.filename(url), content_type: io.content_type })
    end
  end

  def self.kind_for(content_type)
    case content_type.to_s
    when /\Aimage\// then "photo"
    when /\Avideo\// then "video"
    when /\Aaudio\// then "audio"
    else "document"
    end
  end
end
