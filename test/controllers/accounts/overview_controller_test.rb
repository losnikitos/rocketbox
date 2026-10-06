# frozen_string_literal: true

require "test_helper"

class Accounts::OverviewControllerTest < ActionDispatch::IntegrationTest
  test "draws recipes between their input folders, style and output folder" do
    admin = sign_in_as(users(:admin_user))
    style = Style.create!(name: "Moody", body: "Low key light.")
    recipe = Recipe.create!(name: "Portrait", kind: "generate_image", body: "p", style:,
      inputs: [ { "folder_id" => folders(:customer).id }, { "folder_id" => folders(:customer).id } ], output_folder: folders(:ready))
    feature = Recipe.create!(name: "Fully booked", kind: "feature", inputs: [ { "folder_id" => folders(:ready).id } ], layer_slug: "fully-booked",
      output_folder: folders(:photobank_logo))

    get overview_url(account: admin.id)

    assert_select "a[data-id=?][href=?]", "recipe-#{recipe.id}", recipe_path(recipe, account: admin.id), text: "Portrait"
    assert_select "a[data-id=?][href=?]", "folder-#{folders(:customer).id}", library_folders_path("inbox", "customer", account: admin.id), text: "Inbox / Customer"
    assert_select "[data-id=?]", "style-#{style.id}", text: "Moody"
    assert_select "[data-id=?]", "layer-fully-booked", text: "Fully booked"
    edges = JSON.parse(css_select("[data-controller=flow]").first["data-flow-edges-value"])
    assert_equal [ [ "folder-#{folders(:customer).id}", "recipe-#{recipe.id}" ], [ "style-#{style.id}", "recipe-#{recipe.id}" ],
      [ "recipe-#{recipe.id}", "folder-#{folders(:ready).id}" ] ], edges.select { it.include?("recipe-#{recipe.id}") }
    assert_includes edges, [ "recipe-#{feature.id}", "folder-#{folders(:photobank_logo).id}" ]
  end
end
