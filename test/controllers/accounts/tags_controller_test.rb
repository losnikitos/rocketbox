# frozen_string_literal: true

require "test_helper"

class Accounts::TagsControllerTest < ActionDispatch::IntegrationTest
  test "admin creates a tag from the search, or gets the existing one" do
    sign_in_as(users(:admin_user))

    assert_difference -> { Tag.count } => 1 do
      post tags_url, params: { name: "#Fade" }, as: :json
    end
    tag = Tag.find_by!(name: "fade")
    assert_equal({ "id" => tag.id, "name" => "fade" }, response.parsed_body)

    assert_no_difference -> { Tag.count } do
      post tags_url, params: { name: "fade" }, as: :json
    end
    assert_equal tag.id, response.parsed_body["id"]

    post tags_url, params: { name: "two words" }, as: :json
    assert_response :unprocessable_entity
  end

  test "customers can't create tags" do
    sign_in_as(users(:lazaro_nixon))

    assert_no_difference -> { Tag.count } do
      post tags_url, params: { name: "fade" }, as: :json
    end
  end
end
