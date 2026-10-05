# frozen_string_literal: true

require "test_helper"

class Accounts::RecipeRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    @media = LibraryMedia.create!(kind: "photo", tag: tags(:interior), user: @admin)
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
    @recipe = recipes(:cinematic)
  end

  test "run screen preselects the media and shows video options without saving" do
    other = LibraryMedia.create!(kind: "photo", tag: tags(:interior), user: @admin,
      file: { io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg" })

    assert_no_difference -> { RecipeRun.count } do
      get new_recipe_run_url(@recipe, media_ids: { 0 => @media.id }, account: @admin.id)
    end
    assert_response :success
    assert_select "input[name='media_ids[0]'][value=?][checked]", @media.id.to_s
    assert_select "input[name='media_ids[0]'][value=?]:not([checked])", other.id.to_s
    assert_select "legend", text: /Interior\s+· Inbox/
    assert_select "input[name='recipe_run[options][model]'][value='grok-imagine-video-1.5'][checked]"
    assert_equal %w[grok-imagine-video-1.5 grok-imagine-video], css_select("input[name='recipe_run[options][model]']").map { it["value"] }
    assert_select "a[href='/admin/models']", text: "Manage models"
    assert_select "select[name='recipe_run[options][duration]'] option[selected]", text: "8 s"
    assert_select "[name='recipe_run[options][quality]']", count: 0
    assert_select "textarea[name='recipe_run[extra_prompt]']"
    assert_select "button", text: /Generate/
  end

  test "generate saves the options and enqueues the job; the result lands in the photobank with the source tag" do
    assert_difference -> { RecipeRun.count } => 1, -> { LibraryMedia.photobank.count } => 1, -> { SmmPost.count } => 0 do
      assert_enqueued_with(job: GenerateJob) do
        post recipe_runs_url(@recipe), params: { media_ids: { 0 => @media.id },
          recipe_run: { extra_prompt: "Make it snow.", options: { model: "grok-imagine-video", aspect_ratio: "", resolution: "480p", duration: "5", quality: "low" } } }
      end
    end
    run = @media.input_runs.sole
    assert_redirected_to %r{/library/photobank/#{run.generated_media.id}\b}
    assert_equal [ tags(:interior), "video" ], [ run.generated_media.tag, run.generated_media.kind ]
    assert_equal "Make it snow.", run.extra_prompt
    assert_equal({ "model" => "grok-imagine-video", "resolution" => "480p", "duration" => "5" }, run.options)
    assert_equal({ model: "grok-imagine-video", resolution: "480p", duration: 5, provider: :xai }, run.ai_options)
    assert_equal "running", run.status

    get new_recipe_run_url(@recipe, account: @admin.id)
    assert_select "h2", text: "Made with #{@recipe.name}"
    assert_select "a[href=?]", library_photobank_media_path(run.generated_media, account: @admin.id)
  end

  test "picking an OpenAI model swaps in OpenAI's options and runs on OpenAI" do
    recipe = Recipe.create!(name: "Polish", body: "Polish the shot.", output_collection: "photobank", output_tag: tags(:interior),
      inputs: [ { "collection" => "inbox", "tag_id" => tags(:interior).id } ])

    get new_recipe_run_url(recipe, account: @admin.id, recipe_run: { extra_prompt: "Warmer.", options: { model: "gpt-image-2" } })
    assert_response :success
    assert_select "textarea[name='recipe_run[extra_prompt]']", text: "Warmer."
    assert_select "input[name='recipe_run[options][model]'][value='gpt-image-2'][checked]"
    assert_select "input[type=radio][name='recipe_run[options][aspect_ratio]'][value='9:16'][checked]"
    assert_select "input[type=radio][name='recipe_run[options][resolution]'][value='2k'][checked]"
    assert_equal %w[1K 2K 4K], css_select("input[name='recipe_run[options][resolution]']").map { it.parent.text.strip }
    assert_select "input[type=radio][name='recipe_run[options][quality]'][value=''][checked]"
    assert_select "select[name='recipe_run[options][aspect_ratio]']", count: 0

    get new_recipe_run_url(recipe, account: @admin.id, recipe_run: { options: { model: "grok-imagine-image-2.0", aspect_ratio: "4:5", resolution: "4k", quality: "high" } })
    assert_select "input[name='recipe_run[options][aspect_ratio]']", count: 0
    assert_select "input[name='recipe_run[options][resolution]'][value='2k'][checked]"
    assert_select "input[name='recipe_run[options][resolution]'][value='4k']", count: 0
    assert_select "input[name='recipe_run[options][quality]'][value=''][checked]"

    post recipe_runs_url(recipe), params: { media_ids: { 0 => @media.id },
      recipe_run: { options: { model: "gpt-image-2", aspect_ratio: "1:1", resolution: "4k", quality: "high", duration: "5" } } }
    run = @media.input_runs.sole
    assert_equal({ model: "gpt-image-2", size: "2880x2880", quality: "high", output_format: "jpeg", provider: :openai }, run.ai_options)
  end

  test "starts from the recipe's options; picks override them and drop what the new model lacks" do
    recipe = Recipe.create!(name: "Polish", body: "Polish the shot.", output_tag: tags(:interior), inputs: [ { "collection" => "inbox", "tag_id" => tags(:interior).id } ],
      options: { "model" => "gpt-image-2", "aspect_ratio" => "1:1", "resolution" => "4k", "quality" => "high" })

    get new_recipe_run_url(recipe, account: @admin.id)
    assert_select "input[name='recipe_run[options][model]'][value='gpt-image-2'][checked]"
    assert_select "input[name='recipe_run[options][aspect_ratio]'][value='1:1'][checked]"
    assert_select "input[name='recipe_run[options][resolution]'][value='4k'][checked]"
    assert_select "input[name='recipe_run[options][quality]'][value='high'][checked]"

    get new_recipe_run_url(recipe, account: @admin.id, recipe_run: { options: { model: "grok-imagine-image-2.0", quality: "high" } })
    assert_select "select[name='recipe_run[options][aspect_ratio]'] option[selected]", text: "1:1"
    assert_select "input[name='recipe_run[options][resolution]'][value='2k'][checked]"
    assert_select "input[name='recipe_run[options][quality]'][value=''][checked]"
  end

  test "a recipe taking a style offers every style as an input; the run keeps the pick" do
    style = Style.create!(name: "Film", body: "35mm grain.")
    recipe = Recipe.create!(name: "Polish", body: "Polish the shot.", takes_style: true, output_tag: tags(:interior), inputs: [ { "collection" => "inbox", "tag_id" => tags(:interior).id } ])

    get new_recipe_run_url(recipe, account: @admin.id)
    assert_select "label:has(input[type=radio][name=style_id][value=?][checked])", style.id.to_s, text: /Film\s+35mm grain/

    post recipe_runs_url(recipe), params: { media_ids: { 0 => @media.id }, style_id: style.id }
    assert_equal style, @media.input_runs.sole.style
  end

  test "rejects options xAI doesn't offer and media that don't fit the input" do
    assert_difference -> { RecipeRun.count } => 0, -> { LibraryMedia.count } => 0 do
      post recipe_runs_url(@recipe), params: { media_ids: { 0 => @media.id }, recipe_run: { options: { model: "grok-imagine-video-1.5", resolution: "8k" } } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Resolution 8k isn't available/

    @media.update!(tag: tags(:exterior))
    assert_no_difference -> { RecipeRun.count } do
      post recipe_runs_url(@recipe), params: { media_ids: { 0 => @media.id } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Pick a different matching photo for every input/
  end
end
