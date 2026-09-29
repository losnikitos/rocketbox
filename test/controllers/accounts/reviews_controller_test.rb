# frozen_string_literal: true

require "test_helper"

class Accounts::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @review = @user.reviews.create!(
      source: "fresha", customer_name: "Marco Rossi", rating: 4, body: "Best fade in town.",
      media: [ { io: file_fixture("logo.png").open, filename: "cut.png", content_type: "image/png" } ]
    )
  end

  test "lists active reviews and archives and restores them" do
    get reviews_url
    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", reviews_path, text: /Reviews/
    assert_select "##{dom_id(@review)}", text: /Marco Rossi.*Best fade in town/m
    assert_select "[aria-label='4 out of 5 stars']"
    assert_select "##{dom_id(@review)} span", text: "Fresha"

    patch review_url(@review)
    assert_redirected_to reviews_url
    assert @review.reload.archived?
    get reviews_url
    assert_select "##{dom_id(@review)}", count: 0
    get reviews_url(archived: 1)
    assert_select "##{dom_id(@review)} button", text: "Restore"

    patch review_url(@review)
    assert_redirected_to reviews_url(archived: 1)
    assert_not @review.reload.archived?
  end

  test "tabs filter active reviews by source and pages through them" do
    @user.reviews.create!(source: "google", customer_name: "Archived Al", rating: 5, archived_at: Time.current)
    21.times { |i| @user.reviews.create!(source: "google", customer_name: "Guest #{i}", rating: 5, created_at: i.minutes.ago) }

    get reviews_url
    assert_select "nav[aria-label='Secondary'] a[aria-selected='true']", text: /All\s*22/
    assert_select "nav[aria-label='Secondary'] a", text: /Google\s*21/
    assert_select "nav[aria-label='Secondary'] a", text: /Fresha\s*1/
    assert_select "nav[aria-label='Secondary'] a", text: /Trustpilot/, count: 0
    assert_select "nav[aria-label='Secondary'] a", text: /Archived\s*1/

    get reviews_url(source: "google")
    assert_select "ul li[id^='review_']", count: 20
    assert_select "##{dom_id(@review)}", count: 0
    assert_select "a[rel='next'][href=?]", reviews_path(source: "google", page: 2)

    get reviews_url(source: "google", page: 2)
    assert_select "ul li[id^='review_']", count: 1, text: /Guest 20/
    assert_select "a[rel='next']", count: 0

    get reviews_url(archived: 1, source: "fresha")
    assert_select "ul li[id^='review_']", count: 1, text: /Archived Al/
  end

  test "photos tab lists active reviews with media" do
    @user.reviews.create!(source: "google", customer_name: "No Pics", rating: 5)
    @user.reviews.create!(source: "google", customer_name: "Old Pics", rating: 5, archived_at: Time.current,
      media: [ { io: file_fixture("logo.png").open, filename: "old.png", content_type: "image/png" } ])

    get reviews_url(photos: 1)
    assert_select "nav[aria-label='Secondary'] a[aria-selected='true']", text: /Photos\s*1/
    assert_select "ul li[id^='review_']", count: 1
    assert_select "##{dom_id(@review)}"
  end

  test "other accounts' reviews are hidden and only admins delete" do
    assert_no_difference -> { Review.count } do
      delete review_url(@review)
    end
    assert_redirected_to reviews_url

    sign_in_as(users(:admin_user))
    patch review_url(@review)
    assert_response :not_found

    assert_difference -> { Review.count } => -1 do
      delete review_url(@review, account: @user.id)
    end
  end

  test "active admin edits keep attachments when no files are picked" do
    sign_in_as(users(:admin_user))
    patch admin_review_url(@review), params: { review: { customer_name: "Marco R.", avatar: "", media: [ "" ] } }
    assert_equal "Marco R.", @review.reload.customer_name
    assert_equal 1, @review.media.count
  end

  test "validates source, rating and media type" do
    assert_not @user.reviews.new(customer_name: "A", rating: 5).valid?
    assert_not @user.reviews.new(source: "yelp", customer_name: "A", rating: 5).valid?
    assert_not @user.reviews.new(source: "google", customer_name: "A", rating: 0).valid?
    assert_not @user.reviews.new(source: "google", customer_name: "A", rating: 6).valid?
    assert_not @user.reviews.new(source: "google", customer_name: "A", rating: 5,
      media: [ { io: StringIO.new("x"), filename: "a.pdf", content_type: "application/pdf" } ]).valid?
  end
end
