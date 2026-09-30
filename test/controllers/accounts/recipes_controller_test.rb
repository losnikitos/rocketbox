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

    post recipes_url, params: { recipe: { name: "Story teaser", workflow: "User", prompt: "p" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Workflow is not included in the list"

    post recipes_url, params: { recipe: { name: "Story teaser", workflow: "TwoPhotoStory", prompt: "Film look", texts: { text_1: "Open" } } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Texts can't be blank"

    assert_difference -> { Recipe.where(workflow: "ImagesToVideo").count } do
      post recipes_url, params: { recipe: { name: "Second cinematic", workflow: "ImagesToVideo", prompt: "Neon night vibe" } }
    end
    assert_equal "Neon night vibe", Recipe.find_by!(name: "Second cinematic").prompt

    get new_recipe_url(account: @admin.id)
    assert_select "input[type=radio][name='recipe[workflow]'][value=?]", "TwoPhotoStory"
    assert_select "input[type=radio][name='recipe[workflow]'][value=?]", "ImagesToVideo"
    assert_select "fieldset[data-workflow=TwoPhotoStory][disabled] input[name='recipe[texts][text_1]']"

    post recipes_url, params: { recipe: {
      name: "Story teaser", workflow: "TwoPhotoStory", prompt: "Film look",
      texts: { text_1: "This bank holiday we work as usual", text_2: "Tap link below to book", junk: "x" },
      examples: [ image("a.jpg"), image("b.jpg") ]
    } }
    assert_redirected_to recipes_url(account: @admin.id)
    recipe = Recipe.find_by!(name: "Story teaser")
    assert_equal "story", recipe.format
    assert_equal 2, recipe.input_count
    assert_equal %w[text_1 text_2], recipe.texts.keys
    assert_equal %w[a.jpg b.jpg], recipe.examples.map { it.filename.to_s }.sort

    kept, removed = recipe.examples.sort_by { it.filename.to_s }
    get edit_recipe_url(recipe, account: @admin.id)
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value='']", count: 1
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value=?]", kept.signed_id
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value=?]", removed.signed_id
    assert_select "li button[data-action='file-preview#remove']", count: 2
    assert_select "form[action*='examples']", count: 0
    assert_select "input[name='recipe[workflow]']", count: 0
    assert_select "textarea[name='recipe[prompt]']", text: "Film look"
    assert_select "fieldset[data-workflow=TwoPhotoStory]:not([disabled]) input[name='recipe[texts][text_1]'][value=?]", "This bank holiday we work as usual"
    assert_select "article dd", text: "This bank holiday we work as usual"
    assert_select "article dd", text: "Film look", count: 2

    patch recipe_url(recipe), params: { recipe: { name: "Story teaser", examples: [ "", kept.signed_id, image("c.jpg") ] } }
    assert_redirected_to recipes_url(account: @admin.id)
    assert_equal %w[a.jpg c.jpg], recipe.reload.examples.map { it.filename.to_s }.sort

    patch recipe_url(recipe), params: { recipe: { name: "Story teaser", examples: [ "" ] } }
    assert_empty recipe.reload.examples
  end

  test "recipes used by posts can't be removed" do
    @admin = sign_in_as(users(:admin_user))
    recipe = recipes(:cinematic)
    recipe.smm_posts.create!(user: users(:lazaro_nixon), smm_post_media_items: [ SmmPostMediaItem.new(library_media: story_image) ])

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
