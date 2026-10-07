# frozen_string_literal: true

class LibraryMedia < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :folder
  before_validation(on: :create) { self.folder ||= Folder.inbox }
  # Posts outlive their source media; only the join rows go.
  has_many :smm_post_media_items, dependent: :delete_all
  # Generated media outlive their source; only the input rows go.
  has_many :recipe_run_inputs, dependent: :delete_all
  # Versions are the runs this media is the first input of, as in #original; other inputs only fill a slot.
  has_many :source_inputs, -> { where(position: 0) }, class_name: "RecipeRunInput"
  has_many :source_runs, through: :source_inputs, source: :recipe_run
  has_many :generated_media, through: :source_runs
  # The run that made this media; it has a status and an error.
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

  validates :kind, presence: true
  validates :telegram_file_unique_id, uniqueness: true, allow_nil: true
  validates :whatsapp_media_id, uniqueness: true, allow_nil: true

  # Root folders: inbox gets everything the owner sends or uploads, photobank curated media; photobank/ready is final recipe output.
  def business_card? = folder.slug == "business-card"
  def ready? = folder.slug == "ready" && folder.parent&.slug == "photobank"

  # The media this one is ultimately a version of.
  def original = recipe_run&.source_media&.first&.original || self

  # This media and every version made from it, each followed by its own versions.
  # ponytail: one query per node; fine for shallow trees, switch to a recursive CTE if chains get long
  def lineage = [ self, *generated_media.with_attached_file.includes(:recipe_run).order(:created_at).flat_map(&:lineage) ]

  def story_image?
    return false unless file.attached?

    file.content_type.to_s.start_with?("image/") || kind.in?(%w[photo sticker])
  end

  def video?
    return false if !file.attached? || story_image?

    file.content_type.to_s.start_with?("video/") || kind.in?(%w[video video_note animation])
  end

  # Recipes with an input from this media's folder.
  def recipes
    return [] unless story_image?

    Recipe.with_attached_example.ordered.select { it.folder_ids.include?(folder_id) }
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
