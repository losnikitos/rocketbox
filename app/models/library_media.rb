# frozen_string_literal: true

class LibraryMedia < ApplicationRecord
  belongs_to :user, optional: true
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

  enum :media_type, %w[business_card interior exterior logo customer misc].index_by(&:itself),
       validate: { allow_nil: true }

  validates :kind, presence: true
  validates :telegram_file_unique_id, uniqueness: true, allow_nil: true
  validates :whatsapp_media_id, uniqueness: true, allow_nil: true

  def story_image?
    return false unless file.attached?

    file.content_type.to_s.start_with?("image/") || kind.in?(%w[photo sticker])
  end

  def extraction_status
    extracted_info&.dig("status")
  end

  def extracted_account_attributes
    fields = extracted_info&.dig("fields") || {}
    CARD_FIELDS.to_h { |key, column| [ column, fields[key].to_s.strip ] }.compact_blank
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
