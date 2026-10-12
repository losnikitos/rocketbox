# frozen_string_literal: true

require "test_helper"

class Accounts::RubricsControllerTest < ActionDispatch::IntegrationTest
  test "calendar shows a week, or a month from its tab" do
    travel_to Time.zone.local(2029, 12, 30, 8)
    user = sign_in_as(users(:lazaro_nixon))
    user.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready))

    get rubrics_url(date: "2030-01-09")
    assert_select "nav[aria-label=Secondary] a[aria-current=page]", "Week"
    assert_select "nav[aria-label=Secondary] a[href*=?]", "view=month", text: "Month"
    assert_select "section[aria-label=Calendar]" do
      assert_select "h2", "7 – 13 Jan 2030"
      assert_select "a[aria-label='Previous week'][href*=?]", "date=2030-01-02"
      assert_select "li[title]", text: /Morning story/, count: 7
      assert_select "li[title] [aria-label='No fresh media']", count: 7
    end

    get rubrics_url(view: "month", date: "2030-01-09")
    assert_select "nav[aria-label=Secondary] a[aria-current=page]", "Month"
    assert_select "section[aria-label=Calendar]" do
      assert_select "h2", "January 2030"
      assert_select "a[aria-label='Previous month'][href*=?]", "view=month"
      assert_select "li[title]", text: /Morning story/, count: 35
    end
  end

  test "form picks a folder and tags from searchable dropdowns" do
    user = sign_in_as(users(:lazaro_nixon))
    rubric = user.rubrics.create!(name: "Morning story", schedule: "every day at 9am", folder: folders(:ready))

    get edit_rubric_url(rubric)
    assert_select "input[type=hidden][name='rubric[folder_id]'][value=?]", folders(:ready).id.to_s
    assert_select "button[aria-label='From folder']"
    assert_select "input[type=search][aria-label='Search folders']"
    assert_select "fieldset input[type=radio][name='rubric[format]']", 3
    assert_select "input[type=radio][name='rubric[format]'][value=story][checked]"
    assert_select "input[type=checkbox][name='rubric[tag_ids][]']", Tag.count

    patch rubric_url(rubric), params: { rubric: { tag_ids: [ "", tags(:after).id ] } }
    assert_redirected_to rubrics_url
    assert_equal [ tags(:after).id ], rubric.reload.tag_ids
  end
end
