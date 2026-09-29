# frozen_string_literal: true

require "test_helper"

class Accounts::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @review = @user.reviews.create!(
      customer_name: "Marco Rossi", rating: 4, body: "Best fade in town.",
      media: [ { io: file_fixture("logo.png").open, filename: "cut.png", content_type: "image/png" } ]
    )
  end

  test "lists active reviews and archives and restores them" do
    get reviews_url
    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", reviews_path, text: /Reviews/
    assert_select "##{dom_id(@review)}", text: /Marco Rossi.*Best fade in town/m
    assert_select "[aria-label='4 out of 5 stars']"

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

  test "other accounts' reviews are hidden and only admins delete" do
    assert_no_difference -> { Review.count } do
      delete review_url(@review)
    end
    assert_redirected_to reviews_url

    sign_in_as(users(:admin_user))
    patch review_url(@review)
    assert_response :not_found

    patch account_selection_url, params: { user_id: @user.id }
    assert_difference -> { Review.count } => -1 do
      delete review_url(@review)
    end
  end

  test "active admin edits keep attachments when no files are picked" do
    sign_in_as(users(:admin_user))
    patch admin_review_url(@review), params: { review: { customer_name: "Marco R.", avatar: "", media: [ "" ] } }
    assert_equal "Marco R.", @review.reload.customer_name
    assert_equal 1, @review.media.count
  end

  test "validates rating and media type" do
    assert_not @user.reviews.new(customer_name: "A", rating: 0).valid?
    assert_not @user.reviews.new(customer_name: "A", rating: 6).valid?
    assert_not @user.reviews.new(customer_name: "A", rating: 5,
      media: [ { io: StringIO.new("x"), filename: "a.pdf", content_type: "application/pdf" } ]).valid?
  end
end
