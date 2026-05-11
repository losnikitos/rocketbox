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
        @book.chapters.destroy_all
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
          body: build_markdown_body(row.id),
        }
      end

      def build_markdown_body(page_id)
        blocks = []
        cursor = nil

        loop do
          request = { block_id: page_id, page_size: 100 }
          request[:start_cursor] = cursor if cursor.present?

          response = @client.block_children(**request)
          blocks.concat(Array(response.results))
          break unless response.has_more

          cursor = response.next_cursor
        end

        render_blocks_to_markdown(blocks).strip
      rescue StandardError => e
        Rails.logger.warn("Notion::ChapterSync could not load page body for #{page_id}: #{e.class}: #{e.message}")
        ""
      end

      def render_blocks_to_markdown(blocks)
        lines = []

        blocks.each do |block|
          type = block["type"] || block[:type]
          data = block[type] || block[type.to_sym]

          case type
          when "paragraph"
            lines << rich_text_to_plain_text(data["rich_text"] || data[:rich_text])
            lines << ""
          when "heading_1"
            lines << "# #{rich_text_to_plain_text(data["rich_text"] || data[:rich_text])}"
            lines << ""
          when "heading_2"
            lines << "## #{rich_text_to_plain_text(data["rich_text"] || data[:rich_text])}"
            lines << ""
          when "heading_3"
            lines << "### #{rich_text_to_plain_text(data["rich_text"] || data[:rich_text])}"
            lines << ""
          when "bulleted_list_item"
            lines << "- #{rich_text_to_plain_text(data["rich_text"] || data[:rich_text])}"
          when "numbered_list_item"
            lines << "1. #{rich_text_to_plain_text(data["rich_text"] || data[:rich_text])}"
          when "quote"
            lines << "> #{rich_text_to_plain_text(data["rich_text"] || data[:rich_text])}"
            lines << ""
          when "code"
            lines << "```"
            lines << rich_text_to_plain_text(data["rich_text"] || data[:rich_text])
            lines << "```"
            lines << ""
          when "divider"
            lines << "---"
            lines << ""
          when "image"
            lines << image_block_to_markdown(data)
            lines << ""
          end
        end

        lines.join("\n")
      end

      def image_block_to_markdown(image_data)
        image_type = image_data["type"] || image_data[:type]
        image_url = image_data.dig(image_type, "url") || image_data.dig(image_type.to_sym, :url)
        caption = rich_text_to_plain_text(image_data["caption"] || image_data[:caption])
        return "" if image_url.blank?

        "![#{caption}](#{image_url})"
      end

      def rich_text_to_plain_text(rich_text)
        Array(rich_text).map { |segment| segment["plain_text"] || segment[:plain_text] }.join.strip
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
