# frozen_string_literal: true

require "test_helper"

class Accounts::WorkflowsControllerTest < ActionDispatch::IntegrationTest
  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get workflows_url
    assert_redirected_to root_url
  end

  test "admin builds a workflow on the canvas, rejects a folder to folder edge, moves edge ends, moves and removes nodes and deletes it" do
    admin = sign_in_as(users(:admin_user))

    post workflows_url, params: { workflow: { name: "" } }
    assert_response :unprocessable_entity

    post workflows_url, params: { workflow: { name: "Inbox to ready" } }
    workflow = Workflow.last
    assert_redirected_to workflow_url(workflow, account: admin.id)

    get workflow_url(workflow, account: admin.id)
    assert_select "button[form=workflow_add][name=?][value=?]", "workflow[nodes_attributes][0][folder_id]", folders(:ready).id.to_s
    assert_select "button[form=workflow_add][name=?][value=?]", "workflow[nodes_attributes][0][transformation_id]", transformations(:cinematic).id.to_s

    add = ->(attributes) { patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => attributes } } } }
    add.(folder_id: folders(:interior).id, x: 60, y: 80)
    add.(transformation_id: transformations(:cinematic).id, x: 300, y: 80)
    add.(folder_id: folders(:ready).id, x: 540, y: 80)
    input, step, output = workflow.nodes.reload.to_a
    assert_equal [ false, true, false ], [ input, step, output ].map(&:step?)

    connect = ->(from, to) { patch workflow_url(workflow, account: admin.id), params: { workflow: { edges_attributes: { "0" => { from_id: from.id, to_id: to.id } } } } }
    connect.(input, step)
    connect.(step, output)
    assert_equal 2, workflow.edges.count

    connect.(input, output)
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Connect a folder to a transformation, not to another folder."
    assert_equal 2, workflow.edges.count

    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: step.id, x: 320, y: 140 } } } }, as: :json
    assert_response :no_content
    assert_equal [ 320, 140 ], step.reload.then { [ it.x, it.y ] }

    get workflow_url(workflow, account: admin.id, node: step.id)
    edge_in, edge_out = workflow.edges.order(:id).to_a
    assert_select "[data-controller=flow][data-flow-edges-value=?]", [ edge_in, edge_out ].map { [ it.from_id, it.to_id,
      { id: it.id, path: workflow_path(workflow, edge: it.id), frame: "inspector", current: false } ] }.to_json
    assert_select "a[data-id=?][data-x='320'][data-y='140'][data-turbo-frame=inspector][aria-current=true]", step.id.to_s do
      assert_select "[data-flow-input]", 1
    end
    assert_select "turbo-frame#inspector turbo-frame#transformation[src^=?]", transformation_path(transformations(:cinematic))

    media = admin.library_media.create!(kind: "photo", folder: folders(:interior))
    get workflow_url(workflow, account: admin.id, node: input.id)
    assert_select "turbo-frame#inspector ul[aria-label=Media] a[href^=?]", library_item_path(media)

    tagged = admin.library_media.create!(kind: "photo", folder: folders(:interior), tags: [ tags(:before) ])
    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: input.id, tag_id: tags(:before).id } } } }
    assert_equal "#{folders(:interior).path} #before", input.reload.label
    get workflow_url(workflow, account: admin.id, node: input.id)
    assert_select "turbo-frame#inspector ul[aria-label=Media] a", 1
    assert_select "turbo-frame#inspector ul[aria-label=Media] a[href^=?]", library_item_path(tagged)

    get transformation_url(transformations(:cinematic), account: admin.id), headers: { "Turbo-Frame" => "transformation" }
    assert_select "turbo-frame#transformation form#transformation_form[data-turbo-frame=transformation]"

    move = ->(edge, from, to) { patch workflow_url(workflow, account: admin.id), params: { workflow: { edges_attributes: { "0" => { id: edge.id, from_id: from.id, to_id: to.id } } } } }
    move.(edge_in, input, output)
    assert_response :unprocessable_entity
    assert_equal step.id, edge_in.reload.to_id
    move.(edge_out, step, input)
    assert_equal [ [ input.id, step.id ], [ step.id, input.id ] ], workflow.edges.reload.map { [ it.from_id, it.to_id ] }
    assert_equal input.id, edge_out.reload.to_id
    move.(edge_out, step, output)

    get workflow_url(workflow, account: admin.id, edge: edge_out.id)
    assert_select "turbo-frame#inspector h2", "#{step.label} → #{output.label}"
    assert_select "turbo-frame#inspector button", "Remove connection"
    patch workflow_url(workflow, account: admin.id), params: { workflow: { edges_attributes: { "0" => { id: edge_out.id, _destroy: 1 } } } }
    assert_equal [ edge_in ], workflow.edges.reload.to_a

    assert_not folders(:interior).destroy
    assert_not transformations(:cinematic).destroy

    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: step.id, _destroy: 1 } } } }
    assert_equal [ input, output ], workflow.nodes.reload.to_a
    assert_equal 0, workflow.edges.count

    get workflows_url(account: admin.id)
    assert_select "##{dom_id(workflow)} a[href^=?]", workflow_path(workflow), text: "Inbox to ready"

    assert_difference -> { Workflow.count } => -1, -> { WorkflowNode.count } => -2 do
      delete workflow_url(workflow, account: admin.id)
    end
    assert_redirected_to workflows_url(account: admin.id)
  end
end
