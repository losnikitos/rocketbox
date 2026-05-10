# frozen_string_literal: true

module Notion
  class ChapterSync
    class DuplicatePositionError < StandardError; end

    PUBLISHED_STATUS = "Published"
    FREE_ACCESS = "Free"

    def self.call(book:)
      new(book: book).call
    end

    def initialize(book:, client: Notion::Client.new)
      @book = book
      @client = client
    end

    def call
      return if @book.notion_database_id.blank?

      attrs = collect_chapter_attrs
      ensure_unique_positions!(attrs)
      attrs.sort_by! { |a| a[:position] }

      Book.transaction do
        @book.chapters.delete_all
        attrs.each do |a|
          @book.chapters.create!(a)
        end
      end

      Rails.logger.info(
        "Notion::ChapterSync synced #{attrs.size} chapter(s) for book id=#{@book.id} slug=#{@book.slug}"
      )
      attrs
    end

    private

      def collect_chapter_attrs
        results = []
        @client.database_query(database_id: @book.notion_database_id, page_size: 100) do |page|
          page.results.each do |row|
            attrs = extract_attrs(row)
            results << attrs if attrs
          end
        end
        results
      end

      def extract_attrs(row)
        properties = row.properties

        # Use dig for nested API keys — Hashie::Mash mixes in Enumerable#select, so
        # `properties["Access"].select` is filtering, not the Notion "select" property.
        status = properties.dig("Status", "status", "name")
        return nil unless status == PUBLISHED_STATUS

        title_segments = properties.dig("Chapter", "title")
        title = title_segments&.map { |t| t["plain_text"] || t[:plain_text] }&.join&.strip
        if title.blank?
          Rails.logger.warn("Notion::ChapterSync skipping row #{row.id}: missing title")
          return nil
        end

        position = properties.dig("Position", "number")
        if position.nil?
          Rails.logger.warn("Notion::ChapterSync skipping row #{row.id} (#{title}): missing Position")
          return nil
        end

        access = properties.dig("Access", "select", "name")

        {
          title: title,
          position: position.to_i,
          free: access == FREE_ACCESS,
        }
      end

      def ensure_unique_positions!(attrs)
        positions = attrs.map { |a| a[:position] }
        duplicates = positions.tally.select { |_, count| count > 1 }.keys
        return if duplicates.empty?

        raise DuplicatePositionError,
          "Notion DB #{@book.notion_database_id} has duplicate Position values: #{duplicates.join(', ')}"
      end
  end
end
