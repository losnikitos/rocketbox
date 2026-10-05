# frozen_string_literal: true

require "test_helper"

class Accounts::ShotsControllerTest < ActionDispatch::IntegrationTest
  test "admin adds a shot; the index has a tab per group and filters by it" do
    @admin = sign_in_as(users(:admin_user))
    Shot.create!(name: "Red Carpet", body: "A premiere.", group: "Events")

    post shots_url, params: { shot: { name: "Empty Chair", group: "Daily", body: "The empty chair." } }
    assert_redirected_to shots_url(group: "Daily", account: @admin.id)

    get shots_url(group: "Daily", account: @admin.id)
    assert_select "a[href=?][aria-selected='true']", shots_path(group: "Daily", account: @admin.id), text: /Daily/
    assert_select "a[href=?]", shots_path(group: "Events", account: @admin.id), text: /Events/
    assert_select "##{dom_id(Shot.find_by!(name: "Empty Chair"))}", text: /The empty chair/
    assert_select "li", text: /Red Carpet/, count: 0

    recipe = Recipe.create!(name: "Chair", body: "p", inputs: [ { "folder_id" => folders(:photobank_interior).id } ], shot_group: "Daily")
    get recipe_url(recipe, account: @admin.id)
    assert_select "label:has(input[type=radio][name=shot_id])", text: /Empty Chair\s+The empty chair/
  end
end
