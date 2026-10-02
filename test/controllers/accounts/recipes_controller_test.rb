# frozen_string_literal: true

require "test_helper"

class Accounts::RecipesControllerTest < ActionDispatch::IntegrationTest
  test "admin creates a recipe with examples; the index previews it with tags and a use CTA" do
    @admin = sign_in_as(users(:admin_user))

    post recipes_url, params: { recipe: { name: "Team collage", format: "post", body: "p",
      media_type_ids: [ media_types(:interior).id ], examples: [ image("a.jpg") ] } }
    assert_redirected_to recipes_url(account: @admin.id)
    recipe = Recipe.find_by!(name: "Team collage")
    assert_equal %w[a.jpg], recipe.examples.map { it.filename.to_s }

    get recipes_url(account: @admin.id)
    assert_select "##{dom_id(recipe)}" do
      assert_select "img[alt='a.jpg']"
      assert_select "a[href=?]", edit_recipe_path(recipe, account: @admin.id), text: "Team collage"
      assert_select "ul[aria-label=Tags] li", text: media_types(:interior).name
      assert_select "a[href=?]", new_recipe_post_path(recipe, account: @admin.id), text: /Use recipe/
    end

    get edit_recipe_url(recipe, account: @admin.id)
    assert_select "input[type=hidden][name='recipe[examples][]'][form=recipe_form][value=?]", recipe.examples.first.signed_id

    patch recipe_url(recipe), params: { recipe: { examples: [ "" ] } }
    assert_empty recipe.reload.examples
  end

  private

    def image(name)
      Rack::Test::UploadedFile.new(StringIO.new("img"), "image/jpeg", original_filename: name)
    end
end
