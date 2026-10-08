# frozen_string_literal: true

require "test_helper"

class Accounts::TransformationsControllerTest < ActionDispatch::IntegrationTest
  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get transformations_url
    assert_redirected_to root_url
  end

  test "admin creates, lists, edits and deletes a transformation; one a recipe uses stays" do
    admin = sign_in_as(users(:admin_user))

    post transformations_url, params: { transformation: { name: "", kind: "generate_image", body: "" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Name can't be blank"
    assert_select "li", text: "Body can't be blank"

    post transformations_url, params: { transformation: { name: "Collage", kind: "generate_image", body: "Collage" } }
    transformation = Transformation.last
    assert_redirected_to transformation_url(transformation, account: admin.id)

    get transformations_url(account: admin.id)
    assert_select "##{dom_id(transformation)}" do
      assert_select "a[href^=?]", transformation_path(transformation), text: "Collage"
      assert_select "p", text: "Generation · Image"
      assert_select "[popover] a[href^=?][data-turbo-method=delete]", transformation_path(transformation)
    end

    get transformation_url(transformation, account: admin.id, transformation: { kind: "generate_video" })
    assert_select "textarea[name='transformation[body]']"
    assert_select "input[name='transformation[name]'][value=Collage]"

    patch transformation_url(transformation, account: admin.id), params: { transformation: { name: "Team collage", body: "Team collage" } }
    assert_equal [ "Team collage", "Team collage" ], transformation.reload.then { [ it.name, it.body ] }

    delete transformation_url(transformations(:cinematic), account: admin.id)
    assert Transformation.exists?(transformations(:cinematic).id)
    assert_match "dependent recipes", flash[:alert]

    assert_difference -> { Transformation.count }, -1 do
      delete transformation_url(transformation, account: admin.id)
    end
    assert_redirected_to transformations_url(account: admin.id)
  end

  test "tabs filter transformations by type" do
    admin = sign_in_as(users(:admin_user))
    image = Transformation.create!(name: "Collage", kind: "generate_image", body: "Collage")

    get transformations_url(account: admin.id, kind: "generate_image")
    assert_select "##{dom_id(image)}"
    assert_select "##{dom_id(transformations(:cinematic))}", count: 0
    assert_select "a[href*='kind=generate_image'][aria-selected=true]"
  end
end
