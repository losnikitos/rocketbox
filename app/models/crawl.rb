# frozen_string_literal: true

class Crawl < ApplicationRecord
  PROVIDERS = { "firecrawl" => "Firecrawl", "getbro" => "GetBro" }.freeze

  # Extracted field => User column.
  FIELDS = {
    "business_name" => :business_name,
    "phone" => :phone,
    "address" => :address,
    "website" => :homepage_url,
    "business_description" => :business_description,
    "business_hours" => :business_hours
  }.freeze

  belongs_to :link
  has_many :suggestions, -> { order(:id) }, dependent: :destroy
  delegate :url, :user, to: :link

  enum :status, %w[pending done failed].index_by(&:itself)

  validates :provider, inclusion: { in: PROVIDERS.keys }
  validates :data_instruction, presence: true

  normalizes :screenshot_url, with: ->(url) { url if url.match?(%r{\Ahttps?://}i) }

  def account_attributes
    FIELDS.to_h { |key, column| [ column, extracted&.dig(key).to_s.strip ] }.compact_blank
  end

  def logo_url
    extracted&.dig("logo_url").presence
  end

  def photo_urls
    Array(extracted&.dig("photo_urls"))
  end

  def video_urls
    Array(extracted&.dig("video_urls"))
  end

  def media_urls
    photo_urls + video_urls
  end

  # One pending row per proposed change; values the account already has are skipped.
  def create_suggestions!
    imported = user.library_media.where(source_url: media_urls).pluck(:source_url)
    rows = account_attributes.filter_map { |column, value| [ FIELDS.key(column), value ] unless user[column].to_s.strip == value }
    rows << [ "logo", logo_url ] if logo_url
    rows += (photo_urls - imported).map { |url| [ "photo", url ] } + (video_urls - imported).map { |url| [ "video", url ] }
    rows.each { |key, value| suggestions.create!(key: key, value: value) }
  end
end
