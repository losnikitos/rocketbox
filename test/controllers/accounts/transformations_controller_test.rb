# frozen_string_literal: true

require "test_helper"

class Accounts::TransformationsControllerTest < ActionDispatch::IntegrationTest
  FRAME = { "Turbo-Frame" => "transformation" }.freeze

  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get transformation_url(transformations(:cinematic)), headers: FRAME
    assert_redirected_to root_url
  end

  test "admin edits a step's transformation in the workflow's inspector frame; outside it opens the step" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Editing")
    step = workflow.nodes.create!(transformation_attributes: { kind: "generate_image" })
    transformation = step.transformation

    get transformation_url(transformation, account: admin.id)
    assert_redirected_to workflow_url(workflow, account: admin.id, node: step.id)

    get transformation_url(transformation, account: admin.id), headers: FRAME
    assert_select "turbo-frame#transformation form[data-turbo-frame=transformation]" do
      assert_select "textarea[name='transformation[body]']"
      assert_select "input[name='transformation[name]'][value=?]", "Image"
      assert_select "p", text: "Generation · Image"
      assert_select "[name='transformation[kind]']", count: 0
    end

    patch transformation_url(transformation, account: admin.id), params: { transformation: { name: "Team collage", body: "Team collage", kind: "generate_video" } }, headers: FRAME
    assert_redirected_to transformation_url(transformation, account: admin.id)
    assert_equal [ "Team collage", "Team collage", "generate_image" ], transformation.reload.then { [ it.name, it.body, it.kind ] }
    autosave = FRAME.merge("X-Autosave" => "1", "Accept" => "application/json")
    patch transformation_url(transformation, account: admin.id), params: { transformation: { body: "" } }, headers: autosave
    assert_response :ok
    assert_predicate transformation.reload.body, :blank?
    # The canvas node and inspector heading take the saved name and options.
    assert_select "turbo-stream[action=update][target=node_#{step.id}_label] template", text: "Team collage"
    assert_select "turbo-stream[target=node_#{step.id}_heading]"
    assert_select "turbo-stream[target=node_#{step.id}_kind] template", text: transformation.options_label
    # A model switch saves with the old model's options it doesn't offer refilled.
    patch transformation_url(transformation, account: admin.id), params: { transformation: { options: { model: "gpt-image-2", resolution: "4k" } } }, headers: autosave
    patch transformation_url(transformation, account: admin.id), params: { transformation: { options: { model: "grok-imagine-image-2.0", resolution: "4k" } } }, headers: autosave
    assert_response :ok
    assert_equal [ "grok-imagine-image-2.0", "2k" ], transformation.reload.options.values_at("model", "resolution")
    patch transformation_url(transformation, account: admin.id), params: { transformation: { name: "" } }, headers: autosave
    assert_response :unprocessable_entity
    assert_equal "Name can't be blank", response.parsed_body["error"]
    patch transformation_url(transformation, account: admin.id), params: { transformation: { name: "" } }, headers: FRAME
    assert_response :unprocessable_entity
    assert_select "turbo-frame#transformation li", text: "Name can't be blank"

    zoom = workflow.nodes.create!(transformation_attributes: { kind: "zoom" }).transformation
    get transformation_url(zoom, account: admin.id), headers: { "Turbo-Frame" => "generation_options" }
    assert_select "input[type=radio][name='transformation[options][zoom]'][value=in][checked]"
    assert_select "select[name='transformation[options][duration]'] option", count: 5

    get transformation_url(transformations(:cinematic), account: admin.id)
    assert_response :not_found
  end

  test "a scripted type's original reel streams for the form's preview" do
    admin = sign_in_as(users(:admin_user))
    get original_transformations_url("doppler", account: admin.id)
    assert_response :success
    assert_equal "video/mp4", response.media_type
    get original_transformations_url("smart_crop", account: admin.id)
    assert_response :not_found
  end
end
