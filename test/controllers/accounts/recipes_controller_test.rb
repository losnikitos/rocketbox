# frozen_string_literal: true

require "test_helper"

class Accounts::RecipesControllerTest < ActionDispatch::IntegrationTest
  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get recipes_url
    assert_redirected_to root_url
  end

  test "admin creates a recipe with inputs and examples; the index previews it and links to a run" do
    @admin = sign_in_as(users(:admin_user))

    post recipes_url, params: { recipe: { name: "Team collage", kind: "audio", body: "p", inputs: [ input(:photobank_interior) ] } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Kind is not included in the list"

    post recipes_url, params: { recipe: { name: "Team collage", body: "p", output_folder_id: folders(:ready).id,
      inputs: [ input(:photobank_interior), input(:customer), { folder_id: "" } ], examples: [ image("a.jpg") ] } }
    assert_redirected_to recipes_url(account: @admin.id)
    recipe = Recipe.find_by!(name: "Team collage")
    assert recipe.generate_image?
    assert_equal [ { "folder_id" => folders(:photobank_interior).id }, { "folder_id" => folders(:customer).id } ], recipe.inputs
    assert_equal %w[a.jpg], recipe.examples.map { it.filename.to_s }

    get recipes_url(account: @admin.id)
    assert_select "##{dom_id(recipe)}" do
      assert_select "img[alt='a.jpg']"
      assert_select "a[href=?]", new_recipe_run_path(recipe, account: @admin.id), text: "Team collage"
      assert_select "ul[aria-label=Inputs] li a[href=?]", library_folders_path("photobank", "interior", account: @admin.id), text: "Photobank / Interior"
      assert_select "[aria-label=Output] a[href=?]", library_folders_path("photobank", "ready", account: @admin.id), text: "Photobank / Ready"
      assert_select "[popover] a[href=?]", edit_recipe_path(recipe, account: @admin.id)
      assert_select "[popover] a[href^='/app/recipes/#{recipe.id}?'][data-turbo-method=delete]"
    end

    get edit_recipe_url(recipe, account: @admin.id)
    assert_select "#recipe_inputs > div", 2
    assert_select "select[name='recipe[inputs][][folder_id]'] option[selected][value=?]", folders(:customer).id.to_s
    assert_select "select[name='recipe[output_folder_id]'] option[selected][value=?]", folders(:ready).id.to_s
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value=?]", recipe.examples.first.signed_id

    patch recipe_url(recipe), params: { recipe: { kind: "generate_video", output_folder_id: folders(:photobank_interior).id, inputs: [ input(:exterior) ], examples: [ "" ] } }
    assert_redirected_to recipes_url(account: @admin.id)
    assert recipe.reload.video?
    assert_equal [ [ folders(:exterior).id ], folders(:photobank_interior) ], [ recipe.folder_ids, recipe.output_folder ]
    assert_empty recipe.examples

    assert_difference -> { Recipe.count }, -1 do
      delete recipe_url(recipe)
    end
  end

  test "admin sets default options; the kind refresh swaps image options for video ones" do
    @admin = sign_in_as(users(:admin_user))

    get new_recipe_url(account: @admin.id)
    assert_select "input[type=radio][name='recipe[kind]'][value=generate_image][checked]"
    assert_equal %w[generate_image generate_video stitch], css_select("input[name='recipe[kind]']").map { it["value"] }
    assert_select "turbo-frame#generation_options input[name='recipe[options][model]'][value='gpt-image-2.5-flare'][checked]"
    assert_equal %w[gpt-image-2.5-flare gpt-image-2 grok-imagine-image-2.0], css_select("input[name='recipe[options][model]']").map { it["value"] }
    assert_select "input[type=checkbox][name='recipe[takes_style]']"
    assert_select "select[name='recipe[shot_group]'][disabled]"
    assert_select "button[name=refresh][formaction=?][formmethod=get][data-turbo-frame=generation_options]", new_recipe_path(account: @admin.id)

    get new_recipe_url(account: @admin.id, recipe: { kind: "generate_video", options: { model: "gpt-image-2", aspect_ratio: "4:5" } })
    assert_select "input[name='recipe[options][model]'][value='grok-imagine-video-1.5'][checked]"
    assert_select "select[name='recipe[options][aspect_ratio]'] option[selected]", text: "9:16"
    assert_select "select[name='recipe[options][duration]'] option[selected]", text: "8 s"

    post recipes_url, params: { recipe: { name: "Square", body: "p", output_folder_id: folders(:ready).id, inputs: [ input(:photobank_interior) ],
      options: { model: "gpt-image-2", aspect_ratio: "1:1", resolution: "4k", quality: "" } } }
    recipe = Recipe.find_by!(name: "Square")
    assert_equal({ "model" => "gpt-image-2", "aspect_ratio" => "1:1", "resolution" => "4k" }, recipe.options)

    get edit_recipe_url(recipe, account: @admin.id)
    assert_select "input[name='recipe[options][aspect_ratio]'][value='1:1'][checked]"
    assert_select "button[name=refresh][formaction=?]", edit_recipe_path(recipe, account: @admin.id)

    patch recipe_url(recipe), params: { recipe: { options: { model: "gpt-image-2", aspect_ratio: "2:1" } } }
    assert_response :unprocessable_entity
    assert_select "li", text: /Aspect ratio 2:1 isn't available/
  end

  test "index tabs filter by input folder; recipes reading several go under multiple inputs" do
    @admin = sign_in_as(users(:admin_user))
    reel = Recipe.create!(name: "Reel", kind: "stitch", inputs: [ input(:photobank_interior), input(:photobank_interior) ])
    collage = Recipe.create!(name: "Collage", body: "p", inputs: [ input(:photobank_interior), input(:photobank_customer) ])

    get recipes_url(account: @admin.id)
    headers = css_select("section h2").map(&:text)
    assert_includes headers, "Photobank / Interior"
    assert_equal "Multiple inputs", headers.last
    assert_select "section", text: /Multiple inputs.*Collage/m

    get recipes_url(account: @admin.id, source: folders(:interior).id.to_s)
    assert_select "section h2", count: 0
    assert_select "nav[aria-label='Secondary'] a[aria-selected='true']", text: %r{Inbox / Interior\s+1}
    assert_select "nav[aria-label='Secondary'] a[href=?]", recipes_path(source: folders(:photobank_interior).id.to_s, account: @admin.id), text: %r{Photobank / Interior\s+1}
    assert_select "nav[aria-label='Secondary'] a", text: /Multiple inputs\s+1/
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", recipes_path(account: @admin.id)
    assert_select "##{dom_id(recipes(:cinematic))}"
    assert_select "##{dom_id(reel)}", count: 0

    get recipes_url(account: @admin.id, source: "multiple")
    assert_select "##{dom_id(collage)}"
    assert_select "##{dom_id(reel)}", count: 0
  end

  private

    def input(folder) = { folder_id: folders(folder).id }

    def image(name)
      Rack::Test::UploadedFile.new(StringIO.new("img"), "image/jpeg", original_filename: name)
    end
end
