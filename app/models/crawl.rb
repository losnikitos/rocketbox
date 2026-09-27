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
  delegate :url, :user, to: :link

  enum :status, %w[pending done failed].index_by(&:itself)

  validates :provider, inclusion: { in: PROVIDERS.keys }
  validates :data_instruction, presence: true

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
