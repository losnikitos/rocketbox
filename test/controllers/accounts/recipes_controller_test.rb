# frozen_string_literal: true

require "test_helper"

class Accounts::RecipesControllerTest < ActionDispatch::IntegrationTest
  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get recipes_url
    assert_redirected_to root_url
  end

  test "admin creates a recipe with inputs and an example; the index previews it and links to its page" do
    @admin = sign_in_as(users(:admin_user))

    post recipes_url, params: { recipe: { name: "Team collage", kind: "audio", body: "p", inputs: [ input(:photobank_interior) ] } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Kind is not included in the list"

    post recipes_url, params: { recipe: { name: "Team collage", body: "p", output_folder_id: folders(:ready).id,
      inputs: [ input(:photobank_interior), input(:customer), { folder_id: "" } ], example: image("a.jpg") } }
    recipe = Recipe.find_by!(name: "Team collage")
    assert_redirected_to recipe_url(recipe, account: @admin.id)
    assert recipe.generate_image?
    assert_equal [ { "folder_id" => folders(:photobank_interior).id }, { "folder_id" => folders(:customer).id } ], recipe.inputs
    assert_equal "a.jpg", recipe.example.filename.to_s

    get recipes_url(account: @admin.id)
    assert_select "##{dom_id(recipe)}" do
      assert_select "img[alt='a.jpg']"
      assert_select "a[href=?]", recipe_path(recipe, account: @admin.id), text: "Team collage"
      assert_select "[popover] a[href^='/app/recipes/#{recipe.slug}?'][data-turbo-method=delete]"
    end

    get recipe_url(recipe, account: @admin.id)
    assert_select "#recipe_input_list > [role=group]", 2
    assert_select "input[type=hidden][name='recipe[inputs][][folder_id]'][value=?]", folders(:customer).id.to_s
    assert_select "#recipe_input_list button[value=?][aria-current=true]", folders(:customer).id.to_s, text: "Inbox / Customer" do
      assert_select "svg.text-emerald-500"
    end
    assert_select "input[type=hidden][name='recipe[output_folder_id]'][value=?]", folders(:ready).id.to_s
    assert_select "label:has(input[type=file][name='recipe[example]'][accept='image/*']) img[src*='a.jpg']"

    patch recipe_url(recipe), params: { commit: "save", recipe: { kind: "generate_video", output_folder_id: folders(:photobank_interior).id, inputs: [ input(:exterior) ], example: image("b.jpg") } }
    assert_redirected_to recipe_url(recipe, account: @admin.id)
    assert recipe.reload.video?
    assert_equal [ [ folders(:exterior).id ], folders(:photobank_interior) ], [ recipe.folder_ids, recipe.output_folder ]
    assert_equal "b.jpg", recipe.example.filename.to_s

    patch recipe_url(recipe), params: { commit: "save", recipe: { kind: "stitch", layer_slug: "caption",
      layer_steps: [ { line1: "The", line2: "coffee" }, { line1: "", line2: "tools" }, { line1: "", line2: "" } ] } }
    assert_equal [ { "line1" => "The", "line2" => "coffee" }, { "line2" => "tools" } ], recipe.reload.layer_steps
    get recipe_url(recipe, account: @admin.id)
    assert_select "input[name='recipe[layer_steps][][line2]']", 3

    assert_difference -> { Recipe.count }, -1 do
      delete recipe_url(recipe)
    end
  end

  test "admin sets default options; the kind refresh swaps image options for video ones" do
    @admin = sign_in_as(users(:admin_user))

    get new_recipe_url(account: @admin.id)
    assert_select "input[type=radio][name='recipe[kind]'][value=generate_image][checked]"
    assert_equal %w[generate_image generate_video stitch feature], css_select("input[name='recipe[kind]']").map { it["value"] }
    assert_select "turbo-frame#generation_options input[type=hidden][name='recipe[options][model]'][value='gpt-image-2.5-flare']"
    assert_equal %w[gpt-image-2.5-flare gpt-image-2 grok-imagine-image-2.0], css_select("turbo-frame#generation_options button[data-pick-target=option]").map { it["value"] }
    assert_select "section[aria-label=Media] input[type=checkbox][name='on[media]'][checked]"
    %w[Style Shot Review Layer].each { assert_select "section[aria-label=#{it}] fieldset[disabled]" }
    assert_select "button[name=refresh][formaction=?][formmethod=get][data-turbo-frame=generation_options]", new_recipe_path(account: @admin.id)
    assert_select "button[name=commit]", count: 0

    get new_recipe_url(account: @admin.id, recipe: { kind: "generate_video", options: { model: "gpt-image-2", aspect_ratio: "4:5" } })
    assert_select "input[type=hidden][name='recipe[options][model]'][value='grok-imagine-video-1.5']"
    assert_select "input[type=radio][name='recipe[options][aspect_ratio]'][value='9:16'][checked]"
    assert_select "select[name='recipe[options][duration]'] option[selected]", text: "8 s"

    post recipes_url, params: { recipe: { name: "Square", body: "p", output_folder_id: folders(:ready).id, inputs: [ input(:photobank_interior) ],
      options: { model: "gpt-image-2", aspect_ratio: "1:1", resolution: "4k", quality: "" } } }
    recipe = Recipe.find_by!(name: "Square")
    assert_equal({ "model" => "gpt-image-2", "aspect_ratio" => "1:1", "resolution" => "4k" }, recipe.options)

    get recipe_url(recipe, account: @admin.id)
    assert_select "input[name='recipe[options][aspect_ratio]'][value='1:1'][checked]"
    assert_select "button[name=refresh][formaction=?]", recipe_path(recipe, account: @admin.id)
    assert_select "button[name=refresh_inputs][formaction=?][data-turbo-frame=recipe_inputs]", recipe_path(recipe, account: @admin.id)

    patch recipe_url(recipe), params: { commit: "save", recipe: { options: { model: "gpt-image-2", aspect_ratio: "2:1" } } }
    assert_response :unprocessable_entity
    assert_select "li", text: /Aspect ratio 2:1 isn't available/
  end

  test "index lists recipes newest first" do
    @admin = sign_in_as(users(:admin_user))
    reel = Recipe.create!(name: "Reel", kind: "stitch", inputs: [ input(:photobank_interior), input(:photobank_interior) ])

    get recipes_url(account: @admin.id)
    assert_equal dom_id(reel), css_select("main li[id^='recipe_']").first["id"]
    assert_select "nav[aria-label='Secondary']", count: 0
  end

  test "admin drops a recipe into a group; the index lists it under that group" do
    @admin = sign_in_as(users(:admin_user))
    reel = Recipe.create!(name: "Reel", kind: "stitch", inputs: [ input(:photobank_interior) ])

    patch recipe_url(reel), params: { recipe: { group: " Promo " } }, headers: { "HTTP_REFERER" => recipes_url(account: @admin.id) }
    assert_redirected_to recipes_url(account: @admin.id)
    assert_equal "Promo", reel.reload.group
    assert_includes Recipe.groups, "Promo"

    get recipes_url(account: @admin.id)
    assert_select "section[data-move-to=Promo]" do
      assert_select "form[action=?] input[name=to][value=Promo]", rename_group_recipes_path(account: @admin.id)
      assert_select "##{dom_id(reel)} a[draggable=true][data-move-url=?]", recipe_path(reel, account: @admin.id)
    end
    assert_select "section[data-move-to='']", text: /Ungrouped/
    assert_select "form input[name='recipe[group]'][data-drag-move-target=value]"

    patch recipe_url(reel), params: { recipe: { group: "" } }
    assert_nil reel.reload.group
  end

  test "admin renames a group; every recipe in it moves to the new name" do
    @admin = sign_in_as(users(:admin_user))
    a, b, other = %w[A B C].map { Recipe.create!(name: it, kind: "stitch", inputs: [ input(:photobank_interior) ], group: "Promo") }
    other.update!(group: "Other")

    patch rename_group_recipes_url(account: @admin.id), params: { from: "Promo", to: " Sale " }
    assert_redirected_to recipes_url(account: @admin.id)
    assert_equal %w[Sale Sale Other], [ a, b, other ].map { it.reload.group }
  end

  class RunTest < ActionDispatch::IntegrationTest
    setup do
      @admin = sign_in_as(users(:admin_user))
      @media = LibraryMedia.create!(kind: "photo", folder: folders(:interior), user: @admin)
      @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
      @recipe = recipes(:cinematic)
    end

    test "the page preselects the media and shows video options without saving" do
      other = LibraryMedia.create!(kind: "photo", folder: folders(:interior), user: @admin,
        file: { io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg" })

      assert_no_difference -> { RecipeRun.count } do
        get recipe_url(@recipe, media_ids: { 0 => @media.id }, account: @admin.id)
      end
      assert_response :success
      assert_select "input[name='media_ids[0]'][value=?][checked]", @media.id.to_s
      assert_select "input[name='media_ids[0]'][value=?]:not([checked])", other.id.to_s
      assert_select "[role=group][aria-label='Input 1'] button[aria-current=true]", text: /Inbox \/ Interior/ do
        assert_select "svg.text-emerald-500"
      end
      assert_select "input[type=hidden][name='recipe[options][model]'][value='grok-imagine-video-1.5']"
      assert_equal %w[grok-imagine-video-1.5 grok-imagine-video], css_select("turbo-frame#generation_options button[data-pick-target=option]").map { it["value"] }
      assert_select "a[href='/admin/models']", text: "Manage models"
      assert_select "select[name='recipe[options][duration]'] option[selected]", text: "8 s"
      assert_select "[name='recipe[options][quality]']", count: 0
      assert_select "textarea[name='recipe[body]']", text: @recipe.body
      assert_equal [ "Save and Run", "Run", "Save" ], css_select("button[name=commit]").map { it.text.strip }
    end

    test "save and run saves the recipe and enqueues the job; the result lands in the recipe output folder" do
      assert_difference -> { RecipeRun.count } => 1, -> { folders(:photobank_interior).library_media.count } => 1, -> { SmmPost.count } => 0 do
        assert_enqueued_with(job: GenerateJob) do
          patch recipe_url(@recipe), params: { commit: "save_run", media_ids: { 0 => @media.id },
            recipe: { body: "Make it snow.", options: { model: "grok-imagine-video", aspect_ratio: "", resolution: "480p", duration: "5", quality: "low" } } }
        end
      end
      run = @media.input_runs.sole
      assert_redirected_to library_item_url(run.generated_media, account: @admin.id)
      assert_equal [ folders(:photobank_interior), "video" ], [ run.generated_media.folder, run.generated_media.kind ]
      assert_equal [ "Make it snow.", "Make it snow." ], [ @recipe.reload.body, run.prompt ]
      assert_equal({ "model" => "grok-imagine-video", "resolution" => "480p", "duration" => "5" }, @recipe.options)
      assert_equal({ model: "grok-imagine-video", aspect_ratio: "9:16", resolution: "480p", duration: 5, provider: :xai }, run.ai_options)
      assert_equal "running", run.status

      get recipe_url(@recipe, account: @admin.id)
      assert_select "h2", text: "Made with #{@recipe.name}"
      assert_select "a[href=?]", library_item_path(run.generated_media, account: @admin.id)
    end

    test "run sends the edited prompt and options for that run only; a type change needs a save" do
      patch recipe_url(@recipe), params: { commit: "run", media_ids: { 0 => @media.id },
        recipe: { body: "Make it snow.", options: { model: "grok-imagine-video", duration: "5" } } }
      run = @media.input_runs.sole
      assert_redirected_to library_item_url(run.generated_media, account: @admin.id)
      assert_equal [ "Make it snow.", { "model" => "grok-imagine-video", "aspect_ratio" => "9:16", "resolution" => "720p", "duration" => "5" } ], [ run.prompt, run.options ]
      assert_equal [ "Slow cinematic push-in on the shop.", {} ], [ @recipe.reload.body, @recipe.options ]

      assert_no_difference -> { RecipeRun.count } do
        patch recipe_url(@recipe), params: { commit: "run", media_ids: { 0 => @media.id }, recipe: { kind: "generate_image" } }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Save to change the type/
      assert @recipe.reload.video?
    end

    test "picking an OpenAI model swaps in OpenAI's options and runs on OpenAI" do
      recipe = Recipe.create!(name: "Polish", body: "Polish the shot.", output_folder: folders(:photobank_interior),
        inputs: [ { "folder_id" => folders(:interior).id } ])

      get recipe_url(recipe, account: @admin.id, recipe: { body: "Warmer.", options: { model: "gpt-image-2" } })
      assert_response :success
      assert_select "textarea[name='recipe[body]']", text: "Warmer."
      assert_select "input[type=hidden][name='recipe[options][model]'][value='gpt-image-2']"
      assert_select "input[type=radio][name='recipe[options][aspect_ratio]'][value='9:16'][checked]"
      assert_select "input[type=radio][name='recipe[options][resolution]'][value='2k'][checked]"
      assert_equal %w[1K 2K 4K], css_select("input[name='recipe[options][resolution]']").map { it.parent.text.strip }
      assert_select "input[type=radio][name='recipe[options][quality]'][value=''][checked]"
      assert_select "select[name='recipe[options][aspect_ratio]']", count: 0

      get recipe_url(recipe, account: @admin.id, recipe: { options: { model: "grok-imagine-image-2.0", aspect_ratio: "4:5", resolution: "4k", quality: "high" } })
      assert_equal %w[9:16 1:1 4:3 16:9], css_select("input[name='recipe[options][aspect_ratio]']").map { it["value"] }
      assert_select "input[name='recipe[options][aspect_ratio]'][value='9:16'][checked]"
      assert_select "input[name='recipe[options][resolution]'][value='2k'][checked]"
      assert_select "input[name='recipe[options][resolution]'][value='4k']", count: 0
      assert_select "input[name='recipe[options][quality]'][value=''][checked]"

      patch recipe_url(recipe), params: { commit: "run", media_ids: { 0 => @media.id },
        recipe: { options: { model: "gpt-image-2", aspect_ratio: "1:1", resolution: "4k", quality: "high" } } }
      run = @media.input_runs.sole
      assert_equal({ model: "gpt-image-2", size: "2880x2880", quality: "high", output_format: "jpeg", provider: :openai }, run.ai_options)
    end

    test "inputs from the same folder start on different media while there are enough" do
      other = LibraryMedia.create!(kind: "photo", folder: folders(:interior), user: @admin,
        file: { io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg" })
      recipe = Recipe.create!(name: "Pair", body: "Pair them.", inputs: [ { "folder_id" => folders(:interior).id } ] * 2)

      get recipe_url(recipe, account: @admin.id)
      picks = [ 0, 1 ].map { css_select("input[name='media_ids[#{it}]'][checked]").sole["value"] }
      assert_equal [ @media.id, other.id ].map(&:to_s).sort, picks.sort

      get recipe_url(recipe, media_ids: { 1 => @media.id }, account: @admin.id)
      assert_select "input[name='media_ids[0]'][value=?][checked]", other.id.to_s
    end

    test "changing an input's folder refreshes its media" do
      recipe = Recipe.create!(name: "Polish", body: "Polish the shot.", inputs: [ { "folder_id" => folders(:exterior).id } ])

      get recipe_url(recipe, account: @admin.id)
      assert_select "input[name='media_ids[0]']", count: 0

      get recipe_url(recipe, account: @admin.id, recipe: { inputs: [ { folder_id: folders(:interior).id } ] })
      assert_select "input[name='media_ids[0]'][value=?][checked]", @media.id.to_s
    end

    test "a recipe's fixed style goes into every run; switching the section off clears it" do
      style = Style.create!(name: "Film", body: "35mm grain.")
      recipe = Recipe.create!(name: "Polish", body: "Polish the shot.", style:, inputs: [ { "folder_id" => folders(:interior).id } ])

      get recipe_url(recipe, account: @admin.id)
      assert_select "section[aria-label=Style] fieldset:not([disabled]) select[name='recipe[style_id]'] option[selected][value=?]", style.id.to_s

      patch recipe_url(recipe), params: { commit: "run", media_ids: { 0 => @media.id }, recipe: { body: "Polish the shot." } }
      run = @media.input_runs.sole
      assert_equal [ style, "Polish the shot.\n\n35mm grain." ], [ run.style, run.prompt ]

      patch recipe_url(recipe), params: { commit: "save", recipe: { style_id: "" } }
      assert_nil recipe.reload.style
    end

    test "a section switched on before it has a value stays on through the refresh" do
      recipe = Recipe.create!(name: "Polish", body: "Polish the shot.", inputs: [ { "folder_id" => folders(:interior).id } ])

      get recipe_url(recipe, account: @admin.id, on: { shot: 1 }, recipe: { shot_group: "" })
      assert_select "section[aria-label=Shot] input[name='on[shot]'][checked]"
      assert_select "section[aria-label=Shot] fieldset:not([disabled]) select[name='recipe[shot_group]']"
    end

    test "a feature recipe's run renders the picked photo and review into its output folder" do
      ready = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user: @admin,
        file: { io: StringIO.new("img"), filename: "ready.jpg", content_type: "image/jpeg" })
      review = @admin.reviews.create!(source: "google", customer_name: "Dana K.", rating: 5, body: "Best fade in town.")
      recipe = Recipe.create!(name: "Reviews", kind: "feature", layer_slug: "review", takes_review: true, inputs: [ { "folder_id" => folders(:ready).id } ])

      get recipe_url(recipe, account: @admin.id)
      assert_select "input[name='media_ids[0]'][value=?][checked]", ready.id.to_s
      assert_select "label:has(input[type=radio][name=review_id][value=?][checked])", review.id.to_s, text: /Dana K\.\s+Best fade in town/
      assert_select "section[aria-label=Layer] select[name='recipe[layer_slug]'] option[selected][value=review]"

      assert_difference -> { RecipeRun.count } => 1, -> { SmmPost.count } => 0 do
        assert_enqueued_with(job: GenerateJob) do
          patch recipe_url(recipe), params: { commit: "run", media_ids: { 0 => ready.id }, review_id: review.id, recipe: { name: "Reviews" } }
        end
      end
      run = recipe.runs.sole
      assert_redirected_to library_item_url(run.generated_media, account: @admin.id)
      assert_equal [ review, [ ready ], folders(:ready) ], [ run.review, run.source_media, run.generated_media.folder ]

      patch recipe_url(recipe), params: { commit: "run", media_ids: { 0 => ready.id }, recipe: { layer_slug: "daily" } }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Save to change the type or layer/
    end

    test "rejects options xAI doesn't offer and media that don't fit the input" do
      assert_difference -> { RecipeRun.count } => 0, -> { LibraryMedia.count } => 0 do
        patch recipe_url(@recipe), params: { commit: "run", media_ids: { 0 => @media.id }, recipe: { options: { model: "grok-imagine-video-1.5", resolution: "8k" } } }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Resolution 8k isn't available/

      @media.update!(folder: folders(:exterior))
      assert_no_difference -> { RecipeRun.count } do
        patch recipe_url(@recipe), params: { commit: "run", media_ids: { 0 => @media.id }, recipe: { body: @recipe.body } }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Pick a matching photo for every input/
    end
  end

  private

    def input(folder) = { folder_id: folders(folder).id }

    def image(name)
      Rack::Test::UploadedFile.new(StringIO.new("img"), "image/jpeg", original_filename: name)
    end
end
