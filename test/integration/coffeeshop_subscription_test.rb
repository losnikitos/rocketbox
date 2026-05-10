# frozen_string_literal: true

require "test_helper"

class CoffeeshopSubscriptionTest < ActionDispatch::IntegrationTest
  setup do
    Book.find_by(slug: "coffeeshop")&.destroy!
    @book = Book.create!(title: "Coffee Shop", slug: "coffeeshop")
    @free_chapter = @book.chapters.create!(title: "Free chapter", position: 1, free: true)
    @paid_chapter = @book.chapters.create!(title: "Paid chapter", position: 2, free: false)
  end

  test "guest can read free chapter" do
    get books_coffeeshop_chapter_path(chapter: @free_chapter.position)
    assert_response :success
  end

  test "guest cannot read paid chapter" do
    get books_coffeeshop_chapter_path(chapter: @paid_chapter.position)
    assert_redirected_to books_coffeeshop_path
  end

  test "subscribed user can read paid chapter" do
    user = users(:lazaro_nixon)
    user.subscription.update!(active: true)
    sign_in_as(user)

    get books_coffeeshop_chapter_path(chapter: @paid_chapter.position)
    assert_response :success
  end

  test "unsubscribed signed-in user cannot read paid chapter" do
    user = users(:lazaro_nixon)
    user.subscription.update!(active: false)
    sign_in_as(user)

    get books_coffeeshop_chapter_path(chapter: @paid_chapter.position)
    assert_redirected_to books_coffeeshop_path
  end
end
