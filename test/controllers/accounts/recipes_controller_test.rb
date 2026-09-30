# frozen_string_literal: true

require "test_helper"

class Accounts::RecipesControllerTest < ActionDispatch::IntegrationTest
  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get recipes_url
    assert_redirected_to root_url
  end

  test "admin creates a recipe with examples, removes one and adds more on update" do
    @admin = sign_in_as(users(:admin_user))
    get recipes_url(account: @admin.id)
    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", recipes_path(account: @admin.id), text: /Recipes/

    post recipes_url, params: { recipe: { name: "Story teaser", kind: "audio", prompt: "p" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Kind is not included in the list"

    assert_difference -> { Recipe.video.count } do
      post recipes_url, params: { recipe: { name: "Second cinematic", kind: "video", prompt: "Neon night vibe", media_type_id: media_types(:interior).id } }
    end
    assert_equal "Neon night vibe", Recipe.find_by!(name: "Second cinematic").prompt

    get new_recipe_url(account: @admin.id)
    assert_select "input[type=radio][name='recipe[kind]'][value=image][checked]"
    assert_select "input[type=radio][name='recipe[kind]'][value=video]"

    post recipes_url, params: { recipe: { name: "Story teaser", prompt: "Film look", media_type_id: media_types(:interior).id, examples: [ image("a.jpg"), image("b.jpg") ] } }
    assert_redirected_to recipes_url(account: @admin.id)
    recipe = Recipe.find_by!(name: "Story teaser")
    assert recipe.image?
    assert_equal %w[a.jpg b.jpg], recipe.examples.map { it.filename.to_s }.sort

    kept, removed = recipe.examples.sort_by { it.filename.to_s }
    get edit_recipe_url(recipe, account: @admin.id)
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value='']", count: 1
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value=?]", kept.signed_id
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value=?]", removed.signed_id
    assert_select "li button[data-action='file-preview#remove']", count: 2
    assert_select "form[action*='examples']", count: 0
    assert_select "textarea[name='recipe[prompt]']", text: "Film look"

    patch recipe_url(recipe), params: { recipe: { name: "Story teaser", kind: "video", examples: [ "", kept.signed_id, image("c.jpg") ] } }
    assert_redirected_to recipes_url(account: @admin.id)
    assert recipe.reload.video?
    assert_equal %w[a.jpg c.jpg], recipe.examples.map { it.filename.to_s }.sort

    patch recipe_url(recipe), params: { recipe: { name: "Story teaser", examples: [ "" ] } }
    assert_empty recipe.reload.examples
  end

  test "recipes with generations can't be removed" do
    @admin = sign_in_as(users(:admin_user))
    recipe = recipes(:cinematic)
    recipe.generations.create!(source_media: story_image, generated_media: story_image)

    get recipes_url(account: @admin.id)
    assert_select "##{dom_id(recipe)} [popover] a[href^='/admin/recipes/#{recipe.id}']"
    assert_select "##{dom_id(recipe)} [popover] a[href^='/app/recipes/#{recipe.id}?'][data-turbo-method=delete]"
    get admin_recipe_path(recipe)
    assert_response :success

    assert_no_difference -> { Recipe.count } do
      delete recipe_url(recipe)
    end
    assert_redirected_to recipes_url(account: @admin.id)
    assert_difference -> { Recipe.count }, -1 do
      delete recipe_url(recipes(:before_after))
    end
  end

  test "index tabs filter by media type, set on create and edit" do
    @admin = sign_in_as(users(:admin_user))
    get recipes_url(account: @admin.id, media_type: "exterior")
    assert_select "nav[aria-label='Secondary'] a[aria-selected='true']", text: /Exterior/
    assert_select "nav[aria-label='Secondary'] a", text: /Interior\s+1/
    assert_select "##{dom_id(recipes(:cinematic))}", count: 0

    get recipes_url(account: @admin.id, media_type: "interior")
    assert_select "##{dom_id(recipes(:cinematic))}"

    card = media_types(:business_card)
    post recipes_url, params: { recipe: { name: "Card promo", prompt: "p", media_type_id: card.id } }
    recipe = Recipe.find_by!(name: "Card promo")
    assert_equal card, recipe.media_type

    get edit_recipe_url(recipe, account: @admin.id)
    assert_select "select[name='recipe[media_type_id]'] option[selected][value=?]", card.id.to_s
    patch recipe_url(recipe), params: { recipe: { media_type_id: media_types(:exterior).id } }
    assert_equal media_types(:exterior), recipe.reload.media_type

    post recipes_url, params: { recipe: { name: "Bad", prompt: "p", media_type_id: 0 } }
    assert_response :unprocessable_entity
  end

  private

    def image(name)
      Rack::Test::UploadedFile.new(StringIO.new("img"), "image/jpeg", original_filename: name)
    end

    def story_image
      LibraryMedia.create!(kind: "photo", user: users(:lazaro_nixon)).tap do
        it.file.attach(io: StringIO.new("img"), filename: "s.jpg", content_type: "image/jpeg")
      end
    end
end
