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

  belongs_to :user

  enum :status, %w[pending done failed].index_by(&:itself)

  validates :url, format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" }
  validates :provider, inclusion: { in: PROVIDERS.keys }
  validates :data_instruction, presence: true

  normalizes :url, with: ->(url) { url.strip }

  def title
    extracted&.dig("business_name").presence || url[%r{\Ahttps?://([^/?#]+)}i, 1] || url
  end

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
end
