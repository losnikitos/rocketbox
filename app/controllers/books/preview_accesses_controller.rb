# frozen_string_literal: true

module Books
  class PreviewAccessesController < ApplicationController
    skip_before_action :authenticate

    def show
      email = DemoPreviewLink.read(params[:t])

      unless email
        redirect_to new_free_preview_path, alert: "That link is invalid or has expired. Request a new preview below."
        return
      end

      book = Book.find_by(slug: "coffeeshop")
      chapter = book&.chapters&.order(:position)&.first

      if chapter
        redirect_to books_book_chapter_path(book, chapter)
      else
        redirect_to books_path, alert: "Preview is temporarily unavailable."
      end
    end
  end
end
