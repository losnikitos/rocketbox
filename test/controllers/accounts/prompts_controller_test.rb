# frozen_string_literal: true

require "test_helper"

class Accounts::PromptsControllerTest < ActionDispatch::IntegrationTest
  test "admin adds a prompt into a prompt folder, which lists only its own prompts" do
    @admin = sign_in_as(users(:admin_user))
    Prompt.create!(name: "Red Carpet", body: "A premiere.", folder: folders(:prompts_ready))

    post prompts_url, params: { prompt: { name: "Empty Chair", folder_id: folders(:prompts_shots).id, body: "The empty chair." } }
    assert_redirected_to library_folders_url("prompts", "shots")

    get library_folders_url("prompts", "shots", account: @admin.id)
    assert_select "##{dom_id(Prompt.find_by!(name: "Empty Chair"))}", text: /The empty chair/
    assert_select "li", text: /Red Carpet/, count: 0
  end
end
