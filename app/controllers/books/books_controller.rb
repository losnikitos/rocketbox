# frozen_string_literal: true

module Books
  class BooksController < ApplicationController
    skip_before_action :authenticate, except: :show

    before_action :set_book
    before_action :set_reader_context
    before_action :set_chapters

    helper_method :chapter_locked?, :subscribed?

    def index
    end

    def show
      @chapter = @chapters.find { |c| c.slug == params[:chapter_slug] }
      unless @chapter
        redirect_to books_book_path(@book), alert: "That chapter is not available."
        return
      end

      if chapter_locked?(@chapter)
        redirect_to books_book_path(@book), alert: "Subscribe to unlock this chapter."
        nil
      end
    end

    private

      def set_book
        # Resolve by slug only (avoid FriendlyId numeric-id fallback on public URLs).
        @book = Book.includes(:chapters).find_by(slug: params[:slug])
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
        return true unless Current.user

        !chapter.free? && !subscribed?
      end
  end
end
