# frozen_string_literal: true

require "test_helper"

class Accounts::GenerationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    @media = LibraryMedia.create!(kind: "photo", media_type: "interior", user: @admin)
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "draft screen shows the source, recipe and video options without saving" do
    assert_no_difference -> { Generation.count } do
      get new_library_media_generation_url(@media, recipe_id: recipes(:cinematic).id, account: @admin.id)
    end
    assert_response :success
    assert_select "img[src*=?]", "a.jpg"
    assert_select "h2", text: "Cinematic shop reel"
    assert_select "select[name='generation[options][model]'] option[selected]", text: "grok-imagine-video-1.5"
    assert_equal %w[grok-imagine-video-1.5 grok-imagine-video], css_select("select[name='generation[options][model]'] option").map(&:text)
    assert_select "a[href='/admin/models']", text: "Manage models"
    assert_select "select[name='generation[options][duration]'] option[selected]", text: "8 s"
    assert_select "select[name='generation[options][quality]']", count: 0
    assert_select "button", text: /Generate/
    assert_select "a:not([data-turbo-frame])", text: "Cancel"
  end

  test "in the side panel frame, only the panel renders and Cancel reloads just the panel" do
    get new_library_media_generation_url(@media, recipe_id: recipes(:cinematic).id, account: @admin.id), headers: { "Turbo-Frame" => "side_panel" }
    assert_response :success
    assert_select "turbo-frame#side_panel select[name='generation[options][model]']"
    assert_select "a", text: /Source media/, count: 0
    assert_select "turbo-frame#side_panel a[data-turbo-frame=side_panel]", text: "Cancel"
  end

  test "generate saves the options and starts the run; stop and rerun work on it" do
    assert_difference -> { Generation.count } => 1, -> { WorkflowRun.count } => 1, -> { LibraryMedia.photobank.count } => 1, -> { SmmPost.count } => 0 do
      post library_media_generations_url(@media, recipe_id: recipes(:cinematic).id), params: {
        generation: { options: { model: "grok-imagine-video", aspect_ratio: "", resolution: "480p", duration: "5", quality: "low" } }
      }
    end
    generation = @media.generations.sole
    assert_redirected_to %r{/library/photobank/#{generation.generated_media.id}\b}
    assert_equal({ "model" => "grok-imagine-video", "resolution" => "480p", "duration" => "5" }, generation.options)
    assert_equal({ model: "grok-imagine-video", resolution: "480p", duration: 5, provider: :xai }, generation.ai_options)
    assert_equal "running", generation.status

    run = generation.workflow_run
    post stop_library_media_url(generation.generated_media)
    assert_equal "stopped", run.reload.status

    run.step("photos").update!(status: "running")
    run.fail!("boom")
    post rerun_library_media_url(generation.generated_media, key: "photos")
    assert_redirected_to %r{/library/photobank/#{generation.generated_media.id}\b}
    assert_equal "running", run.reload.status
    assert_equal "pending", run.step("photos").status
  end

  test "picking an OpenAI model swaps in OpenAI's options and runs on OpenAI" do
    recipe = Recipe.create!(name: "Polish", workflow: "ImageToImage", media_type: "interior", prompt: "Polish the shot.")

    get new_library_media_generation_url(@media, recipe_id: recipe.id, account: @admin.id, generation: { options: { model: "gpt-image-2" } })
    assert_response :success
    assert_select "select[name='generation[options][model]'] option[selected]", text: "gpt-image-2"
    assert_select "select[name='generation[options][size]'] option[selected]", text: "1024x1536"
    assert_select "select[name='generation[options][aspect_ratio]']", count: 0

    post library_media_generations_url(@media, recipe_id: recipe.id), params: {
      generation: { options: { model: "gpt-image-1-mini", size: "1024x1024", quality: "high", aspect_ratio: "9:16" } }
    }
    generation = @media.generations.sole
    assert_equal({ model: "gpt-image-1-mini", size: "1024x1024", quality: "high", provider: :openai }, generation.ai_options)
  end

  test "rejects options xAI doesn't offer" do
    assert_difference -> { Generation.count } => 0, -> { LibraryMedia.count } => 0 do
      post library_media_generations_url(@media, recipe_id: recipes(:cinematic).id), params: {
        generation: { options: { model: "grok-imagine-video-1.5", resolution: "8k" } }
      }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Resolution 8k isn't available/
  end

  test "a recipe that doesn't fit the media is refused" do
    @media.update!(media_type: "exterior")

    get new_library_media_generation_url(@media, recipe_id: recipes(:cinematic).id, account: @admin.id)
    assert_redirected_to %r{/library/uploads/#{@media.id}\b}
    assert_equal "That recipe doesn't fit this media.", flash[:alert]

    assert_no_difference -> { Generation.count } do
      post library_media_generations_url(@media, recipe_id: recipes(:cinematic).id), params: { generation: { options: { model: "grok-imagine-video-1.5" } } }
    end
  end
end
