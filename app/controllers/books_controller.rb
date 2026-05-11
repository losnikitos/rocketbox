# frozen_string_literal: true

class BooksController < ApplicationController
  skip_before_action :authenticate

  def index
    @books = Book.includes(:chapters).order(:title)
  end
end
