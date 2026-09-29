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

    post recipes_url, params: { recipe: { name: "Story teaser", workflow: "User" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Workflow is not included in the list"

    post recipes_url, params: { recipe: { name: "Second cinematic", workflow: "CinematicShopReel" } }
    assert_select "li", text: "Workflow has already been taken"

    get new_recipe_url(account: @admin.id)
    assert_select "select[name='recipe[workflow]'] option[value=BankHolidayStory]"
    assert_select "select[name='recipe[workflow]'] option[value=CinematicShopReel]", count: 0

    post recipes_url, params: { recipe: {
      name: "Story teaser", workflow: "BankHolidayStory",
      examples: [ image("a.jpg"), image("b.jpg") ]
    } }
    assert_redirected_to recipes_url(account: @admin.id)
    recipe = Recipe.find_by!(name: "Story teaser")
    assert_equal "story", recipe.format
    assert_equal 2, recipe.input_count
    assert_equal %w[a.jpg b.jpg], recipe.examples.map { it.filename.to_s }.sort

    kept, removed = recipe.examples.sort_by { it.filename.to_s }
    get edit_recipe_url(recipe, account: @admin.id)
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form]", count: 2
    assert_select "select[name='recipe[workflow]']", count: 0
    assert_select "article dd", text: "This bank holiday we work as usual"

    delete example_recipe_url(recipe, example_id: removed.id)
    assert_redirected_to edit_recipe_url(recipe, account: @admin.id)
    assert_equal %w[a.jpg], recipe.reload.examples.map { it.filename.to_s }

    patch recipe_url(recipe), params: { recipe: { name: "Story teaser", examples: [ "", kept.signed_id, image("c.jpg") ] } }
    assert_redirected_to recipes_url(account: @admin.id)
    assert_equal %w[a.jpg c.jpg], recipe.reload.examples.map { it.filename.to_s }.sort
  end

  test "recipes used by posts can't be removed" do
    @admin = sign_in_as(users(:admin_user))
    recipe = recipes(:cinematic)
    recipe.smm_posts.create!(user: users(:lazaro_nixon), smm_post_media_items: [ SmmPostMediaItem.new(library_media: story_image) ])

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
