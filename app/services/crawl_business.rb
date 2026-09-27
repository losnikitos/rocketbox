# frozen_string_literal: true

class CrawlBusiness
  MAX_PHOTOS = 24
  MAX_VIDEOS = 8

  FIELDS = {
    "business_name" => "Business or brand name",
    "phone" => "Main phone number, as shown",
    "address" => "Full street address on one line",
    "website" => "The business's own website URL (not the crawled page, a booking platform, or social profile)",
    "business_description" => "One or two sentences on what the business does",
    "business_hours" => "Opening hours, one line per day or range, e.g. \"Mon–Fri 9am–6pm\"",
    "logo_url" => "Direct URL of the business logo (a brand mark, never a photo); empty if none",
    "photo_urls" => "Direct full-size URLs of photos of the business: work, interior, exterior, team",
    "video_urls" => "Direct URLs of video files of the business"
  }.freeze

  # Firecrawl takes JSON Schema; GetBro takes FIELDS as-is.
  JSON_SCHEMA = {
    type: "object",
    properties: FIELDS.to_h do |key, description|
      [ key, key.end_with?("_urls") ? { type: "array", items: { type: "string" }, description: description } : { type: "string", description: description } ]
    end
  }.freeze

  def self.call(crawl:)
    new(crawl:).call
  end

  def self.normalize(raw)
    raw = raw.find { |item| item.is_a?(Hash) } if raw.is_a?(Array)
    raw = raw.is_a?(Hash) ? raw.stringify_keys : {}

    Crawl::FIELDS.keys.to_h { |key| [ key, raw[key].to_s.strip.presence ] }.merge(
      "logo_url" => http_urls(raw["logo_url"]).first,
      "photo_urls" => http_urls(raw["photo_urls"]).first(MAX_PHOTOS),
      "video_urls" => http_urls(raw["video_urls"]).first(MAX_VIDEOS)
    )
  end

  def self.http_urls(value)
    (value.is_a?(Array) ? value : value.to_s.split(%r{\s+|,(?=https?://)}i))
      .map { |url| full_size(url.to_s.strip.sub(/[,;]+\z/, "")) }
      .grep(%r{\Ahttps?://\S+\z}i).uniq
  end

  # CDNs that resize via the URL: Google puts the size after "=" (=s0 is the original);
  # TripAdvisor uses ?w=&h= query params (none is the original).
  def self.full_size(url)
    url
      .sub(%r{\A(https://lh\d\.googleusercontent\.com/[^=?]+)=[\w-]+\z}, '\1=s0')
      .sub(%r{\A(https://dynamic-media-cdn\.tripadvisor\.com/media/[^?]+)\?.*\z}, '\1')
  end

  def initialize(crawl:)
    @crawl = crawl
  end

  def call
    result =
      case @crawl.provider
      when "firecrawl" then Firecrawl.extract(@crawl.url, data_instruction: @crawl.data_instruction, schema: JSON_SCHEMA)
      when "getbro" then GetBro.extract(@crawl.url, data_instruction: @crawl.data_instruction, schema: FIELDS)
      end

    @crawl.update!(status: "done", error: nil, extracted: self.class.normalize(result[:extracted]), screenshot_url: result[:screenshot_url])
  rescue Firecrawl::Error, GetBro::Error, Faraday::Error => e
    @crawl.update!(status: "failed", error: e.message)
  rescue StandardError => e
    @crawl.update!(status: "failed", error: e.message)
    raise
  end
end
