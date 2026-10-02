# frozen_string_literal: true

require "test_helper"

class Accounts::GenerationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    @media = LibraryMedia.create!(kind: "photo", media_type: media_types(:interior), user: @admin)
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "draft screen shows the source, prompt and video options without saving" do
    assert_no_difference -> { Generation.count } do
      get new_library_media_generation_url(@media, prompt_id: prompts(:cinematic).id, account: @admin.id)
    end
    assert_response :success
    assert_select "img[src*=?]", "a.jpg"
    assert_select "h3", text: "Cinematic shop reel"
    assert_select "input[name='generation[options][model]'][value='grok-imagine-video-1.5'][checked]"
    assert_equal %w[grok-imagine-video-1.5 grok-imagine-video], css_select("input[name='generation[options][model]']").map { it["value"] }
    assert_select "a[href='/admin/models']", text: "Manage models"
    assert_select "select[name='generation[options][duration]'] option[selected]", text: "8 s"
    assert_select "[name='generation[options][quality]']", count: 0
    assert_select "button", text: /Generate/
    assert_select "a[aria-label='Back to media']:not([data-turbo-frame])"
  end

  test "in the side panel frame, only the panel renders and Back reloads just the panel" do
    get new_library_media_generation_url(@media, prompt_id: prompts(:cinematic).id, account: @admin.id), headers: { "Turbo-Frame" => "side_panel" }
    assert_response :success
    assert_select "turbo-frame#side_panel input[name='generation[options][model]']"
    assert_select "a", text: /Source media/, count: 0
    assert_select "turbo-frame#side_panel a[data-turbo-frame=side_panel][aria-label='Back to media']"
  end

  test "generate saves the options and enqueues the job" do
    assert_difference -> { Generation.count } => 1, -> { LibraryMedia.photobank.count } => 1, -> { SmmPost.count } => 0 do
      assert_enqueued_with(job: GenerateJob) do
        post library_media_generations_url(@media, prompt_id: prompts(:cinematic).id), params: {
          generation: { extra_prompt: "Make it snow.", options: { model: "grok-imagine-video", aspect_ratio: "", resolution: "480p", duration: "5", quality: "low" } }
        }
      end
    end
    generation = @media.generations.sole
    assert_redirected_to %r{/library/photobank/#{generation.generated_media.id}\b}
    assert_equal "Make it snow.", generation.extra_prompt
    assert_equal({ "model" => "grok-imagine-video", "resolution" => "480p", "duration" => "5" }, generation.options)
    assert_equal({ model: "grok-imagine-video", resolution: "480p", duration: 5, provider: :xai }, generation.ai_options)
    assert_equal "running", generation.status
  end

  test "picking an OpenAI model swaps in OpenAI's options and runs on OpenAI" do
    prompt = Prompt.create!(name: "Polish", media_type: media_types(:interior), body: "Polish the shot.")

    get new_library_media_generation_url(@media, prompt_id: prompt.id, account: @admin.id, generation: { extra_prompt: "Warmer.", options: { model: "gpt-image-2" } })
    assert_response :success
    assert_select "textarea[name='generation[extra_prompt]']", text: "Warmer."
    assert_select "input[name='generation[options][model]'][value='gpt-image-2'][checked]"
    assert_select "input[type=radio][name='generation[options][aspect_ratio]'][value='9:16'][checked]"
    assert_select "input[type=radio][name='generation[options][resolution]'][value='2k'][checked]"
    assert_equal %w[1K 2K 4K], css_select("input[name='generation[options][resolution]']").map { it.parent.text.strip }
    assert_select "input[type=radio][name='generation[options][quality]'][value=''][checked]"
    assert_select "select[name='generation[options][aspect_ratio]']", count: 0

    get new_library_media_generation_url(@media, prompt_id: prompt.id, account: @admin.id, generation: { options: { model: "gpt-image-2", aspect_ratio: "1:1", resolution: "4k", quality: "high" } })
    assert_select "input[name='generation[options][aspect_ratio]'][value='1:1'][checked]"
    assert_select "input[name='generation[options][resolution]'][value='4k'][checked]"
    assert_select "input[name='generation[options][quality]'][value='high'][checked]"

    get new_library_media_generation_url(@media, prompt_id: prompt.id, account: @admin.id, generation: { options: { model: "grok-imagine-image-2.0", aspect_ratio: "4:5", resolution: "4k", quality: "high" } })
    assert_select "input[name='generation[options][aspect_ratio]']", count: 0
    assert_select "input[name='generation[options][resolution]'][value='2k'][checked]"
    assert_select "input[name='generation[options][resolution]'][value='4k']", count: 0
    assert_select "input[name='generation[options][quality]'][value=''][checked]"

    post library_media_generations_url(@media, prompt_id: prompt.id), params: {
      generation: { options: { model: "gpt-image-2", aspect_ratio: "1:1", resolution: "4k", quality: "high", duration: "5" } }
    }
    generation = @media.generations.sole
    assert_equal({ model: "gpt-image-2", size: "2880x2880", quality: "high", output_format: "jpeg", provider: :openai }, generation.ai_options)
  end

  test "starts from the prompt's options; picks override them and drop what the new model lacks" do
    prompt = Prompt.create!(name: "Polish", media_type: media_types(:interior), body: "Polish the shot.",
      options: { "model" => "gpt-image-2", "aspect_ratio" => "1:1", "resolution" => "4k", "quality" => "high" })

    get new_library_media_generation_url(@media, prompt_id: prompt.id, account: @admin.id)
    assert_select "input[name='generation[options][model]'][value='gpt-image-2'][checked]"
    assert_select "input[name='generation[options][aspect_ratio]'][value='1:1'][checked]"
    assert_select "input[name='generation[options][resolution]'][value='4k'][checked]"
    assert_select "input[name='generation[options][quality]'][value='high'][checked]"

    get new_library_media_generation_url(@media, prompt_id: prompt.id, account: @admin.id, generation: { options: { model: "grok-imagine-image-2.0", quality: "high" } })
    assert_select "select[name='generation[options][aspect_ratio]'] option[selected]", text: "1:1"
    assert_select "input[name='generation[options][resolution]'][value='2k'][checked]"
    assert_select "input[name='generation[options][quality]'][value=''][checked]"
  end

  test "rejects options xAI doesn't offer" do
    assert_difference -> { Generation.count } => 0, -> { LibraryMedia.count } => 0 do
      post library_media_generations_url(@media, prompt_id: prompts(:cinematic).id), params: {
        generation: { options: { model: "grok-imagine-video-1.5", resolution: "8k" } }
      }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Resolution 8k isn't available/
  end

  test "a prompt that doesn't fit the media is refused" do
    @media.update!(media_type: media_types(:exterior))

    get new_library_media_generation_url(@media, prompt_id: prompts(:cinematic).id, account: @admin.id)
    assert_redirected_to %r{/library/uploads/#{@media.id}\b}
    assert_equal "That prompt doesn't fit this media.", flash[:alert]

    assert_no_difference -> { Generation.count } do
      post library_media_generations_url(@media, prompt_id: prompts(:cinematic).id), params: { generation: { options: { model: "grok-imagine-video-1.5" } } }
    end
  end
end
