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

    post transformations_url, params: { transformation: { kind: "generate_image", body: "" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Body can't be blank"

    post transformations_url, params: { transformation: { kind: "generate_image", body: "Collage" } }
    transformation = Transformation.last
    assert_redirected_to transformation_url(transformation, account: admin.id)

    get transformations_url(account: admin.id)
    assert_select "##{dom_id(transformation)}" do
      assert_select "a[href^=?]", transformation_path(transformation), text: /Generation · Image/
      assert_select "[popover] a[href^=?][data-turbo-method=delete]", transformation_path(transformation)
    end

    get transformation_url(transformation, account: admin.id, transformation: { kind: "generate_video" })
    assert_select "textarea[name='transformation[body]']"

    patch transformation_url(transformation, account: admin.id), params: { transformation: { body: "Team collage" } }
    assert_equal "Team collage", transformation.reload.body

    delete transformation_url(transformations(:cinematic), account: admin.id)
    assert Transformation.exists?(transformations(:cinematic).id)
    assert_match "dependent recipes", flash[:alert]

    assert_difference -> { Transformation.count }, -1 do
      delete transformation_url(transformation, account: admin.id)
    end
    assert_redirected_to transformations_url(account: admin.id)
  end
end
