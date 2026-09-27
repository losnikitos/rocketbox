# frozen_string_literal: true

class Link < ApplicationRecord
  SOURCES = { "app" => "App", "telegram" => "Telegram", "whatsapp" => "WhatsApp" }.freeze

  belongs_to :user
  has_many :crawls, dependent: :destroy

  validates :url, format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" },
    uniqueness: { scope: :user_id, message: "is already in your links" }
  validates :source, inclusion: { in: SOURCES.keys }

  normalizes :url, with: ->(url) { url.strip }

  def self.urls_in(text)
    text.to_s.scan(%r{https?://\S+}i).map { |url| url.sub(/[.,;:!?)\]'"]+\z/, "") }.uniq
  end

  def title
    crawls.select(&:done?).last&.extracted&.dig("business_name").presence || url[%r{\Ahttps?://([^/?#]+)}i, 1] || url
  end
end
