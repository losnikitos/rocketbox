# frozen_string_literal: true

require "test_helper"

class FeaturesControllerTest < ActionDispatch::IntegrationTest
  setup { @admin = sign_in_as(users(:admin_user)) }

  test "index links to each feature, whose show page holds the settings" do
    get features_url(account: @admin.id)
    assert_select "a[href=?]", feature_path("fully-booked", account: @admin.id), text: /Off/

    get feature_url("fully-booked", account: @admin.id)
    assert_select "input[type=checkbox][name=?]", "feature_setting[enabled]"
    assert_select "select[name=?]", "feature_setting[layer_slug]"
    assert_select "p", text: "Every day at 6pm"
    assert_select "dt", text: "Photos left"
    assert_select "button[disabled]", text: /Compose test draft/

    patch feature_url("fully-booked", account: @admin.id), params: { feature_setting: { enabled: "1" } }
    assert_redirected_to feature_url("fully-booked", account: @admin.id)

    get features_url(account: @admin.id)
    assert_select "a[href=?]", feature_path("fully-booked", account: @admin.id), text: /On/

    get feature_url("daily", account: @admin.id)
    assert_select "select[name=?]", "feature_setting[recipe_id]", 0
    assert_select "a[href=?]", library_ready_path(recipe: 8, account: @admin.id)
  end

  test "test run composes a draft from the picked photo while the feature is off" do
    recipe = Recipe.create!(name: "Poster", body: "Compose.", inputs: [ { "collection" => "photobank", "tag_id" => tags(:working).id } ])
    Feature.find("fully-booked").setting_for(@admin).update!(recipe:)
    source = LibraryMedia.create!(kind: "photo", tag: tags(:working), user: @admin, collection: "photobank",
      file: { io: file_fixture("logo.png").open, filename: "working.png", content_type: "image/png" })
    photos = 2.times.map do
      recipe.run!(media: [ source ]).generated_media.tap do
        it.update!(file: { io: file_fixture("logo.png").open, filename: "ready.png", content_type: "image/png" })
      end
    end

    get feature_url("fully-booked", account: @admin.id)
    assert_select "input[type=radio][name=photo_id]", 2

    post generate_feature_url("fully-booked", account: @admin.id), params: { photo_id: photos.last.id }
    draft = @admin.smm_posts.sole
    assert_redirected_to instagram_post_url(draft, account: @admin.id)
    assert_equal [ photos.last ], draft.library_media.to_a
  end
end
