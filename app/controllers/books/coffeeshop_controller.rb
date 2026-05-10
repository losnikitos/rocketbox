# frozen_string_literal: true

module Books
  class CoffeeshopController < ApplicationController
    skip_before_action :authenticate

    before_action :set_coffeeshop_book
    before_action :set_reader_context
    before_action :set_chapters

    helper_method :chapter_locked?, :subscribed?

    def index
    end

    def show
      n = Integer(params[:chapter], exception: false)
      @chapter = @chapters.find { |c| c.position == n }
      unless @chapter
        redirect_to books_coffeeshop_path, alert: "That chapter is not available."
        return
      end

      if chapter_locked?(@chapter)
        redirect_to books_coffeeshop_path, alert: "Subscribe to unlock this chapter."
        nil
      end
    end

    private

      def set_coffeeshop_book
        @book = Book.includes(:chapters).find_by(slug: "coffeeshop")
        unless @book
          redirect_to root_path
          return
        end
      end

      def set_chapters
        return unless @book

        @chapters = @book.chapters.order(:position).to_a
      end

      def set_reader_context
        @main_container_class = "max-w-6xl"
      end

      def subscribed?
        Current.user&.subscription&.active? || false
      end

      def chapter_locked?(chapter)
        !chapter.free? && !subscribed?
      end
  end
end
