# frozen_string_literal: true

require "test_helper"

class Accounts::WorkflowsControllerTest < ActionDispatch::IntegrationTest
  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get workflows_url
    assert_redirected_to root_url
  end

  test "admin builds a workflow graph, rejects a backwards edge, removes a step with its edges and deletes it" do
    admin = sign_in_as(users(:admin_user))

    post workflows_url, params: { workflow: { name: "" } }
    assert_response :unprocessable_entity

    post workflows_url, params: { workflow: { name: "Inbox to ready" } }
    workflow = Workflow.last
    assert_redirected_to workflow_url(workflow, account: admin.id)

    add = ->(attributes) { patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => attributes } } } }
    add.(kind: "input", folder_id: folders(:interior).id)
    add.(kind: "step", transformation_id: transformations(:cinematic).id)
    add.(kind: "output", folder_id: folders(:ready).id)
    input, step, output = workflow.nodes.reload.to_a
    assert_equal %w[input step output], [ input, step, output ].map(&:kind)

    connect = ->(from, to) { patch workflow_url(workflow, account: admin.id), params: { workflow: { edges_attributes: { "0" => { from_id: from.id, to_id: to.id } } } } }
    connect.(input, step)
    connect.(step, output)
    assert_equal 2, workflow.edges.count

    connect.(output, input)
    assert_response :unprocessable_entity
    assert_equal 2, workflow.edges.count

    get workflow_url(workflow, account: admin.id)
    assert_select "[data-controller=flow][data-flow-edges-value=?]", [ [ "node-#{input.id}", "node-#{step.id}" ], [ "node-#{step.id}", "node-#{output.id}" ] ].to_json
    assert_select "a[data-id=?][href^=?]", "node-#{step.id}", transformation_path(transformations(:cinematic))

    assert_not folders(:interior).destroy
    assert_not transformations(:cinematic).destroy

    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: step.id, _destroy: 1 } } } }
    assert_equal %w[input output], workflow.nodes.reload.map(&:kind)
    assert_equal 0, workflow.edges.count

    get workflows_url(account: admin.id)
    assert_select "##{dom_id(workflow)} a[href^=?]", workflow_path(workflow), text: "Inbox to ready"

    assert_difference -> { Workflow.count } => -1, -> { WorkflowNode.count } => -2 do
      delete workflow_url(workflow, account: admin.id)
    end
    assert_redirected_to workflows_url(account: admin.id)
  end
end
