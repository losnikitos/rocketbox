# frozen_string_literal: true

module Books
  class CoffeeshopController < ApplicationController
    skip_before_action :authenticate

    before_action :set_coffeeshop_book
    before_action :set_reader_context

    def index
    end

    def show
      n = Integer(params[:chapter], exception: false)
      @chapter = @chapters.find { |c| c.position == n }
      unless @chapter
        redirect_to books_coffeeshop_path
        return
      end
    end

    private

      def set_coffeeshop_book
        @book = Book.includes(:chapters).find_by(slug: "coffeeshop")
        unless @book
          redirect_to root_path
          return
        end

        @chapters = @book.chapters
      end

      def set_reader_context
        @main_container_class = "max-w-6xl"
      end
  end
end
