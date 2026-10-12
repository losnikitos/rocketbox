# frozen_string_literal: true

require "test_helper"

class Accounts::RubricsControllerTest < ActionDispatch::IntegrationTest
  test "calendar shows a week, or a month from its tab" do
    user = sign_in_as(users(:lazaro_nixon))
    user.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready))

    get rubrics_url(date: "2030-01-09")
    assert_select "nav[aria-label=Secondary] a[aria-current=page]", "Week"
    assert_select "nav[aria-label=Secondary] a[href*=?]", "view=month", text: "Month"
    assert_select "section[aria-label=Calendar]" do
      assert_select "h2", "7 – 13 Jan 2030"
      assert_select "a[aria-label='Previous week'][href*=?]", "date=2030-01-02"
      assert_select "li[title]", text: /Morning story/, count: 7
      assert_select "ul[aria-label='Running short']", /Morning story\s+has nothing to post/
    end

    get rubrics_url(view: "month", date: "2030-01-09")
    assert_select "nav[aria-label=Secondary] a[aria-current=page]", "Month"
    assert_select "section[aria-label=Calendar]" do
      assert_select "h2", "January 2030"
      assert_select "a[aria-label='Previous month'][href*=?]", "view=month"
      assert_select "li[title]", text: /Morning story/, count: 35
    end
  end
end
