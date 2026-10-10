# frozen_string_literal: true

require "test_helper"

class Accounts::PromptsControllerTest < ActionDispatch::IntegrationTest
  test "admin adds a prompt; the index has a tab per folder and filters by it" do
    @admin = sign_in_as(users(:admin_user))
    Prompt.create!(name: "Red Carpet", body: "A premiere.", folder: "Events")

    post prompts_url, params: { prompt: { name: "Empty Chair", folder: "Shots", body: "The empty chair." } }
    assert_redirected_to prompts_url(folder: "Shots", account: @admin.id)

    get prompts_url(folder: "Shots", account: @admin.id)
    assert_select "a[href=?][aria-selected='true']", prompts_path(folder: "Shots", account: @admin.id), text: /Shots/
    assert_select "a[href=?]", prompts_path(folder: "Events", account: @admin.id), text: /Events/
    assert_select "##{dom_id(Prompt.find_by!(name: "Empty Chair"))}", text: /The empty chair/
    assert_select "li", text: /Red Carpet/, count: 0
  end
end
