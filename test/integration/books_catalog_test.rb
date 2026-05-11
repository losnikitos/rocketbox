# frozen_string_literal: true

require "test_helper"

class BooksCatalogTest < ActionDispatch::IntegrationTest
  test "books page is publicly accessible and lists books" do
    book = Book.create!(title: "Coffee Shop Ops Manual")
    book.chapters.create!(title: "Opening Shift", position: 1, free: true)

    get books_url

    assert_response :success
    assert_select "h1", "Books"
    assert_select "h2", text: "Coffee Shop Ops Manual"
    assert_select "a[href=?]", books_book_path(book), text: "Open preview"
  end

  test "book overview page is publicly accessible" do
    book = Book.create!(title: "Coffee Shop Ops Manual")
    book.chapters.create!(title: "Opening Shift", position: 1, free: true)

    get books_book_path(book)

    assert_response :success
    assert_select "h1", text: "Coffee Shop Ops Manual"
  end
end
