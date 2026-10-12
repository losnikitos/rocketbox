# frozen_string_literal: true

require "test_helper"

class Accounts::RubricsControllerTest < ActionDispatch::IntegrationTest
  test "calendar toggles between a month and a week" do
    user = sign_in_as(users(:lazaro_nixon))
    user.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready))

    get rubrics_url(view: "week", date: "2030-01-09")
    assert_select "section[aria-label=Calendar]" do
      assert_select "h2", "7 – 13 Jan 2030"
      assert_select "nav[aria-label='Calendar view'] a[aria-current=page]", "Week"
      assert_select "a[aria-label='Previous week'][href*=?]", "date=2030-01-02"
      assert_select "li", text: /Morning story/, count: 7
    end

    get rubrics_url(date: "2030-01-09")
    assert_select "section[aria-label=Calendar]" do
      assert_select "h2", "January 2030"
      assert_select "nav[aria-label='Calendar view'] a[aria-current=page]", "Month"
      assert_select "li", text: /Morning story/, count: 35
    end
  end
end
