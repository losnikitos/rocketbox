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

  DEFAULT_DATA_INSTRUCTION = <<~TEXT.strip
    This page is about a small local business (its own website, a Google Maps listing, a booking page like Fresha or Booksy, or a social profile).
    Extract the business profile and media we can reuse on its Instagram. Only use what the page shows; leave a field empty rather than guess.
    - business_name: the business name, without the platform name or location suffix unless it is part of the brand.
    - phone: the main phone number, as shown.
    - address: the full street address on one line.
    - website: the business's own website. Not the page being crawled, a booking platform, a map, or a social profile.
    - business_description: one or two sentences on what the business does and what makes it stand out.
    - business_hours: opening hours, one line per day or day range, e.g. "Mon–Fri 9am–6pm".
    - logo_url: direct URL of the business's logo or brand mark, if shown. Never a photo of the premises, food, work, or people; leave empty if there is no actual logo.
    - photo_urls: direct URLs of photos of the business itself: finished work, interior, exterior, team. Prefer the largest available size. Skip icons, maps, avatars of reviewers, stock images, and placeholders.
    - video_urls: direct URLs of video files (.mp4, .mov, .webm) of the business, if any.
  TEXT

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
