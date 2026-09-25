# frozen_string_literal: true

require "test_helper"

class MonitorMediaGenerationsTest < ActionDispatch::IntegrationTest
  test "admin can open index" do
    sign_in_as(users(:admin_user))

    get monitor_media_generations_path
    assert_response :success
    assert_select "form[action=?]", monitor_media_generations_path
    assert_select "aside nav[aria-label=?]", "Monitor"
  end

  test "admin create enqueues job and redirects to show" do
    sign_in_as(users(:admin_user))

    assert_enqueued_with(job: RunMediaGenerationJob) do
      assert_difference -> { MediaGeneration.count }, 1 do
        post monitor_media_generations_path, params: {
          media_generation: {
            model: "grok-imagine-image-2.0",
            prompt: "a neon barbershop at night"
          }
        }
      end
    end

    generation = MediaGeneration.order(:id).last
    assert generation.in_progress?
    assert_equal "image", generation.media_type
    assert_equal users(:admin_user), generation.user
    assert_redirected_to monitor_media_generation_path(generation)

    follow_redirect!
    assert_response :success
    assert_select "h2", text: /Generation ##{generation.id}/
    assert_match(/in progress/i, response.body)
  end

  test "admin can open show" do
    sign_in_as(users(:admin_user))
    generation = MediaGeneration.create!(
      model: "grok-imagine-image-2.0",
      prompt: "scissors",
      user: users(:admin_user),
      status: :succeeded
    )

    get monitor_media_generation_path(generation)
    assert_response :success
    assert_select "p", text: /scissors/
  end

  test "non-admin redirected to root" do
    sign_in_as(users(:lazaro_nixon))

    get monitor_media_generations_path
    assert_redirected_to root_path
  end

  test "guest redirected to sign in" do
    get monitor_media_generations_path
    assert_redirected_to sign_in_path
  end
end
