# frozen_string_literal: true

require "open-uri"
require "digest/sha1"

module Notion
  class ImageLocalizer
    IMAGE_MARKDOWN_REGEX = /!\[(?<alt>[^\]]*)\]\((?<url>https?:\/\/[^\s)]+)\)/i.freeze

    def self.call(record:, text:)
      new(record: record, text: text).call
    end

    def initialize(record:, text:)
      @record = record
      @text = text.to_s
    end

    def call
      return @text if @text.blank?

      @text.gsub(IMAGE_MARKDOWN_REGEX) do |_match|
        alt = Regexp.last_match[:alt]
        url = Regexp.last_match[:url]

        unless notion_cdn_url?(url)
          next markdown_image(alt, url)
        end

        attachment = existing_attachment_for(url) || attach_remote_image(url)
        local_url = Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
        markdown_image(alt, local_url)
      rescue StandardError => e
        Rails.logger.warn("Notion::ImageLocalizer failed to localize #{url}: #{e.class}: #{e.message}")
        markdown_image(alt, url)
      end
    end

    private

      def notion_cdn_url?(url)
        uri = URI.parse(url)
        host = uri.host.to_s.downcase
        host.end_with?("notion.so", "amazonaws.com")
      rescue URI::InvalidURIError
        false
      end

      def existing_attachment_for(source_url)
        @record.embedded_images.attachments.find do |attachment|
          attachment.blob.metadata["notion_source_url"] == source_url
        end
      end

      def attach_remote_image(source_url)
        filename = suggested_filename(source_url)
        downloaded_io = URI.open(source_url, "User-Agent" => "rocketbox-notion-sync")
        content_type = downloaded_io.content_type.presence || "application/octet-stream"

        blob = ActiveStorage::Blob.create_and_upload!(
          io: downloaded_io,
          filename: filename,
          content_type: content_type,
          metadata: { notion_source_url: source_url }
        )
        @record.embedded_images.attach(blob)
        blob
      ensure
        downloaded_io&.close
      end

      def suggested_filename(source_url)
        path = URI.parse(source_url).path
        name = File.basename(path)
        return name if name.present? && name.include?(".")

        "notion-image-#{Digest::SHA1.hexdigest(source_url)}.bin"
      rescue URI::InvalidURIError
        "notion-image-#{SecureRandom.hex(10)}.bin"
      end

      def markdown_image(alt, url)
        "![#{alt}](#{url})"
      end
  end
end
