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
    assert_select "header form[data-controller=autosave]" do
      assert_select "nav[aria-label=Breadcrumb] a[href^=?]", workflows_path, text: "Workflows"
      assert_select "h1 input[name=?][value=?]", "workflow[name]", "Inbox to ready"
      assert_select "input[type=checkbox][role=switch][name=?]:not([checked])", "workflow[autorun]"
    end
    assert_select "header [id^=workflow-admin-links-#{workflow.id}-] a[href^=?][data-turbo-method=delete]", workflow_path(workflow)
    assert_select "button[form=workflow_add][name=?][value=?]", "workflow[nodes_attributes][0][folder_id]", folders(:ready).id.to_s
    assert_select "button[form=workflow_add][name=?][value=smart_crop]", "workflow[nodes_attributes][0][transformation_attributes][kind]", text: "Smart crop"
    patch workflow_url(workflow, account: admin.id), params: { workflow: { name: "Inbox to ready", autorun: "1" } }, as: :json
    assert_response :no_content
    assert workflow.reload.autorun
    patch workflow_url(workflow, account: admin.id), params: { workflow: { name: "" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "Inbox to ready", workflow.reload.name

    add = ->(attributes) { patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => attributes } } } }
    add.(folder_id: folders(:interior).id, x: 60, y: 80)
    assert_difference -> { Transformation.count } do
      add.(transformation_attributes: { kind: "generate_video" }, x: 300, y: 80)
    end
    add.(folder_id: folders(:ready).id, x: 540, y: 80)
    input, step, output = workflow.nodes.reload.to_a
    assert_equal [ false, true, false ], [ input, step, output ].map(&:step?)
    assert_not_equal transformations(:cinematic), step.transformation
    assert_equal [ "generate_video", Transformation::GenerateVideo.label ], step.transformation.then { [ it.kind, it.name ] }

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
      { id: it.id, slot: nil, path: workflow_path(workflow, edge: it.id, run: workflow.runs.sole.id), frame: "inspector", current: false } ] }.to_json
    assert_select "a[data-id=?][data-x='320'][data-y='140'][data-turbo-frame=inspector][aria-current=true]", step.id.to_s do
      assert_select "[data-flow-input]", 1
    end
    assert_select "turbo-frame#inspector turbo-frame#transformation[src^=?]", transformation_path(step.transformation)

    media = admin.library_media.create!(kind: "photo", folder: folders(:interior))
    get workflow_url(workflow, account: admin.id, node: input.id)
    assert_select "turbo-frame#inspector section[aria-label=Pins] ul[aria-label=Media] li[draggable=true] button[form=workflow_add][value=?]", media.id.to_s

    admin.library_media.create!(kind: "photo", folder: folders(:interior), tags: [ tags(:before) ])
    tagged = admin.library_media.create!(kind: "photo", folder: folders(:interior), tags: [ tags(:before), tags(:after) ])
    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: input.id, tag_ids: [ "", tags(:before).id, tags(:after).id ] } } } }
    assert_equal "#{folders(:interior).path} #after #before", input.reload.label
    get workflow_url(workflow, account: admin.id, node: input.id)
    assert_select "turbo-frame#inspector p", text: "Only media tagged"
    assert_select "turbo-frame#inspector ul[aria-label=Media] li", 1
    assert_select "turbo-frame#inspector ul[aria-label=Media] input[value=?]", tagged.id.to_s
    get workflow_url(workflow, account: admin.id, node: output.id)
    assert_select "turbo-frame#inspector p", text: "Only media tagged"
    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: step.id, tag_ids: [ "", tags(:after).id ] } } } }
    assert_equal [ tags(:after).id ], step.reload.tag_ids
    get workflow_url(workflow, account: admin.id, node: step.id)
    assert_select "turbo-frame#inspector p", text: "Tag what it makes"

    get transformation_url(step.transformation, account: admin.id), headers: { "Turbo-Frame" => "transformation" }
    assert_select "turbo-frame#transformation form#transformation_form[data-turbo-frame=transformation]"
    assert_select "nav[aria-label=Breadcrumb]", 0
    assert_select "a[data-turbo-method=delete]", 0

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
    assert_not step.transformation.destroy

    assert_difference -> { Transformation.count }, -1 do
      patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: step.id, _destroy: 1 } } } }
    end
    assert_equal [ input, output ], workflow.nodes.reload.to_a
    assert_equal 0, workflow.edges.count

    get workflows_url(account: admin.id)
    assert_select "##{dom_id(workflow)} a[href^=?]", workflow_path(workflow), text: "Inbox to ready"

    assert_difference -> { Workflow.count } => -1, -> { WorkflowNode.count } => -2 do
      delete workflow_url(workflow, account: admin.id)
    end
    assert_redirected_to workflows_url(account: admin.id)
  end

  test "workflows list recently edited first, counting node, edge and transformation edits" do
    admin = sign_in_as(users(:admin_user))
    first, second = Workflow.create!(name: "First"), Workflow.create!(name: "Second")
    step = first.nodes.create!(transformation: transformations(:cinematic))
    order = -> { get workflows_url(account: admin.id); css_select("li[id^=workflow_] a").map(&:text) & [ "First", "Second" ] }

    travel 1.minute
    second.nodes.create!(note: "")
    assert_equal [ "Second", "First" ], order.()

    travel 1.minute
    step.transformation.update!(name: "Renamed")
    assert_equal [ "First", "Second" ], order.()
  end

  test "agents read a workflow as Markdown with the agent token, nothing else" do
    credentials = Rails.application.credentials
    credentials.define_singleton_method(:agent_token) { "secret" }
    user = users(:lazaro_nixon)
    workflow = Workflow.create!(name: "Agent read")
    folder, step = [ { folder: folders(:interior) }, { transformation: transformations(:cinematic), tag_ids: [ tags(:after).id ] } ]
      .map { workflow.nodes.create!(it) }
    workflow.edges.create!(from: folder, to: step)
    workflow.nodes.create!(note: "Why it exists")
    media = user.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    run = workflow.latest_run
    run.start!(folder, user)
    md = ->(token) { get workflow_url(workflow, format: :md, node: step.id), headers: { "Authorization" => "Bearer #{token}" } }

    md.("secret")
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_includes response.body, %(```mermaid\nflowchart LR\n  n#{folder.id}[/"#{folders(:interior).path}"/]\n)
    assert_includes response.body, "n#{folder.id} --> n#{step.id}"
    assert_includes response.body, %(### n#{step.id} · Step "#{step.label}" (selected))
    assert_includes response.body, "- Tags it sets on what it makes: #after"
    assert_includes response.body, "~~~text\n#{transformations(:cinematic).body}\n~~~"
    assert_includes response.body, "> Why it exists"
    assert_includes response.body, %(### Step run #{run.step_runs.sole.id} · n#{step.id} "#{step.label}": running)
    assert_includes response.body, "- In: [media #{media.id}](#{library_item_url(media)}) photo [a.jpg]"
    assert_no_match(/&quot;|&#39;/, response.body)

    md.("wrong")
    assert_redirected_to sign_in_url
    get workflow_url(workflow), headers: { "Authorization" => "Bearer secret" }
    assert_redirected_to sign_in_url
  ensure
    credentials.singleton_class.remove_method(:agent_token)
  end

  test "play on a start folder runs the latest run from its newest media and the selected run lists the steps" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Play")
    media = admin.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation: transformations(:cinematic))
    workflow.edges.create!(from: folder, to: step)

    get workflow_url(workflow, account: admin.id)
    assert_select "a[data-id=?] button[form=workflow_play][name=node_id][value=?]", folder.id.to_s, folder.id.to_s
    assert_select "a[data-id=?] button[form=workflow_play][title='Run from here']", step.id.to_s
    assert_select "a[data-id] [role=img]", 0
    assert_select "#workflow_palette section h3", 6

    assert_enqueued_with(job: GenerateJob) { post run_workflow_url(workflow, account: admin.id), params: { node_id: folder.id } }
    run = workflow.runs.sole
    assert_redirected_to workflow_url(workflow, account: admin.id, run: run.id)

    get workflows_url(account: admin.id)
    assert_select "##{dom_id(workflow)}" do
      assert_select "p", /Edited .* ago.*1 run\b.*Last run .* ago/m
      assert_select "span", "Running"
      assert_select "input[type=checkbox][name='workflow[autorun]']:not([checked])"
    end

    get workflow_url(workflow, account: admin.id, run: run.id)
    assert_select "section[aria-label=Runs] a[aria-current=page]", /Run 1/
    assert_select "a[data-id=?] [role=img][aria-label=Working]", step.id.to_s
    assert_select "a[data-id=?] [role=img]", folder.id.to_s, count: 0
    assert_select "section[aria-label=Runs] details[id=?] tbody tr", dom_id(run), count: 1 do
      assert_select "a[href^=?]", workflow_path(workflow, run: run.id, node: step.id), text: step.label
      assert_select "button[popovertarget^=?]", dom_id(media, :quick_view)
    end
    assert_select "#workflow_palette", 1
    assert_select "a[href^=?]", admin_workflow_run_path(run)
    get admin_workflow_run_url(run)
    assert_response :success
    assert_select "a[href^=?]", admin_transformation_run_path(run.step_runs.sole)

    get workflow_url(workflow, account: admin.id, run: run.id, node: step.id)
    assert_select "turbo-frame#inspector" do
      assert_select "dl[aria-label=Stats] dd", text: "Running"
      assert_select "section[aria-label=Inputs] button[popovertarget^=?]", dom_id(media, :quick_view)
      assert_select "section[aria-label=Outputs] p", 0
      assert_select "dl[aria-label=Stats] ~ section[aria-label=Settings] button", text: "Remove from workflow"
    end
    popovers = css_select("[popover]").map { it["id"] }
    assert_equal popovers.uniq, popovers

    get workflow_url(workflow, account: admin.id, run: run.id, node: folder.id)
    pin = "turbo-frame#inspector section[aria-label=Pins] input[name='workflow[nodes_attributes][0][pinned_media_ids][]'][value='#{media.id}']"
    assert_select "#{pin}:not([checked]):not([disabled])"
    assert_select "turbo-frame#inspector section[aria-label=Pins] button", text: "Reset pins", count: 0
    assert_select "a[data-id=?] button[title='Run again']", step.id.to_s, count: 0

    pins = ->(ids) { patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: folder.id, pinned_media_ids: [ "", *ids ] } } } } }
    pins.([ media.id ])
    assert_equal [ media.id ], folder.reload.pinned_media_ids
    draft = workflow.runs.create!
    get workflow_url(workflow, account: admin.id, run: draft.id, node: folder.id)
    assert_select "span", text: "Draft"
    assert_select "#{pin}[checked]"
    assert_select "turbo-frame#inspector section[aria-label=Pins] button", text: "Reset pins"
    pins.([])
    assert_empty folder.reload.pinned_media_ids

    run.step_runs.sole.update!(status: "complete")
    get workflow_url(workflow, account: admin.id, run: run.id)
    assert_select "a[data-id=?] button[form=workflow_play][name=node_id][value=?][title='Run again']", step.id.to_s, step.id.to_s
    assert_enqueued_with(job: GenerateJob) { post run_workflow_url(workflow, account: admin.id, run: run.id), params: { node_id: step.id } }
    assert_equal [ "running" ], run.step_runs.reload.map(&:status)
  end

  test "play on a step whose feeding steps are complete in the run starts it there" do
    admin = sign_in_as(users(:admin_user))
    photo = admin.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    workflow = Workflow.create!(name: "Step play")
    folder, generate, crop, again = [ { folder: folders(:interior) }, { transformation: transformations(:cinematic) },
      *2.times.map { { transformation: Transformation.create!(name: "Smart crop", kind: "smart_crop") } } ].map { workflow.nodes.create!(it) }
    workflow.edges.create!(from: folder, to: generate)
    run = workflow.latest_run
    run.start!(folder, admin)
    made = run.step_runs.sole
    made.generated_media.file.attach(io: StringIO.new("mp4"), filename: "a.mp4", content_type: "video/mp4")
    made.update!(status: "complete")
    [ [ generate, crop ], [ crop, again ] ].each { |from, to| workflow.edges.create!(from:, to:) }

    get workflow_url(workflow, account: admin.id, run: run.id)
    assert_select "a[data-id=?] button[form=workflow_play][name=node_id][value=?][title='Run from here']", crop.id.to_s, crop.id.to_s
    assert_select "a[data-id=?] button[form=workflow_play]", again.id.to_s, count: 0
    assert_select "button[data-flow-target=output][data-v=?][data-w=?][popovertarget=?]", folder.id.to_s, generate.id.to_s, dom_id(photo, :quick_view)
    assert_select "button[data-flow-target=output][data-v=?][data-w=?][popovertarget=?]", generate.id.to_s, crop.id.to_s, dom_id(made.generated_media, :quick_view)
    assert_select "button[data-flow-target=output][data-v=?]", crop.id.to_s, count: 0

    assert_enqueued_with(job: GenerateJob) { post run_workflow_url(workflow, account: admin.id), params: { node_id: crop.id } }
    assert_equal [ made.generated_media ], run.step_runs.find_by!(workflow_node: crop).source_media
    follow_redirect!
    assert_select "a[data-id=?] button[form=workflow_play]", crop.id.to_s, count: 0
    assert_select "a[data-id=?] button[form=workflow_play]", again.id.to_s, count: 0
  end

  test "a folder's arrow shows the media it will give before a step takes any" do
    admin = sign_in_as(users(:admin_user))
    older, newer = %w[a b].map { admin.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "#{it}.jpg", content_type: "image/jpeg" }) }
    older.update!(created_at: 1.day.ago)
    workflow = Workflow.create!(name: "Folder arrow")
    folder, step = [ { folder: folders(:interior) }, { transformation: transformations(:cinematic) } ].map { workflow.nodes.create!(it) }
    workflow.edges.create!(from: folder, to: step)

    get workflow_url(workflow, account: admin.id)
    assert_select "button[data-flow-target=output][data-v=?][data-w=?][popovertarget=?]", folder.id.to_s, step.id.to_s, dom_id(newer, :quick_view)

    folder.update!(pinned_media_ids: [ older.id ])
    get workflow_url(workflow, account: admin.id)
    assert_select "button[data-flow-target=output][data-v=?][data-w=?][popovertarget=?]", folder.id.to_s, step.id.to_s, dom_id(older, :quick_view)
  end

  test "play on a media node runs the latest run from that media" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Play media")
    media = admin.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    source = workflow.nodes.create!(library_media: media)
    step = workflow.nodes.create!(transformation: transformations(:cinematic))
    workflow.edges.create!(from: source, to: step)

    get workflow_url(workflow, account: admin.id)
    assert_select "a[data-id=?] button[form=workflow_play][name=node_id][value=?]", source.id.to_s, source.id.to_s

    assert_enqueued_with(job: GenerateJob) { post run_workflow_url(workflow, account: admin.id), params: { node_id: source.id } }
    assert_equal [ media ], workflow.runs.sole.step_runs.sole.source_media
  end

  test "run plays the selected run from every start folder and media" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Run all")
    photo = admin.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    other = admin.library_media.create!(kind: "photo", folder: folders(:misc), file: { io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg" })
    [ { folder: folders(:interior) }, { library_media: other } ].each do |start|
      workflow.edges.create!(from: workflow.nodes.create!(start), to: workflow.nodes.create!(transformation: transformations(:cinematic).dup))
    end

    get workflow_url(workflow, account: admin.id)
    assert_select "button[form=workflow_play]:not([name])", text: /Run/, count: 2
    assert_select "section[aria-label=Runs] a[aria-current=page] + details + div button[form=workflow_play]"

    post run_workflow_url(workflow, account: admin.id)
    assert_equal [ [ photo ], [ other ] ], workflow.runs.sole.step_runs.map(&:source_media)
  end

  test "a media page's Run in workflow plays a new run of just that media from a start folder it's in" do
    admin = sign_in_as(users(:admin_user))
    workflow = create_workflow("Run media", input: folders(:interior), transformation: transformations(:cinematic))
    start = workflow.nodes.find_by!(folder: folders(:interior))
    picked, newer = 2.times.map { admin.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" }) }
    elsewhere = admin.library_media.create!(kind: "photo", folder: folders(:misc), file: { io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg" })

    assert_no_difference(-> { WorkflowRun.count }) do
      post workflow_runs_url(workflow, account: admin.id), params: { node_id: start.id, media_id: elsewhere.id }
    end
    assert_redirected_to library_item_url(elsewhere, account: admin.id)

    assert_enqueued_with(job: GenerateJob) { post workflow_runs_url(workflow, account: admin.id), params: { node_id: start.id, media_id: picked.id } }
    run = workflow.runs.sole
    assert_redirected_to workflow_url(workflow, account: admin.id, run: run.id, node: start.id)
    assert_equal [ "started", { start.id.to_s => [ picked.id ] }, [ picked ] ], [ run.status, run.picks, run.step_runs.sole.source_media ]
    assert_not_includes run.step_runs.sole.source_media, newer
  end

  test "new run adds a blank run that play runs, the run picker switches runs, and a run is deleted once nothing in it is running" do
    admin = sign_in_as(users(:admin_user))
    admin.library_media.create!(kind: "photo", folder: folders(:interior), file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    workflow = Workflow.create!(name: "Runs")
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation: transformations(:cinematic))
    workflow.edges.create!(from: folder, to: step)
    first = workflow.latest_run
    first.start!(folder, admin)

    assert_difference -> { workflow.runs.count } do
      post workflow_runs_url(workflow, account: admin.id)
    end
    second = workflow.runs.last
    assert_redirected_to workflow_url(workflow, account: admin.id, run: second.id)
    assert_equal "Run 2", second.name

    follow_redirect!
    assert_select "form[action=?][id=workflow_play]", run_workflow_path(workflow, run: second.id)
    assert_select "section[aria-label=Runs] details", 2 do |rows|
      assert_equal [ dom_id(second), dom_id(first) ], rows.map { it["id"] }
    end
    assert_select "section[aria-label=Runs] details[open]", 0
    assert_select "section[aria-label=Runs] a[aria-current=page]", 1
    assert_select "section[aria-label=Runs] a[aria-current=page][href^=?]", workflow_path(workflow, run: second.id)

    get workflow_url(workflow, account: admin.id)
    assert_select "section[aria-label=Runs] details", 2
    assert_select "section[aria-label=Runs] a[aria-current=page][href^=?]", workflow_path(workflow, run: second.id)
    assert_select "section[aria-label=Runs] details[id=?] tbody tr", dom_id(first), count: 1
    assert_select "[popover] a[href^=?][data-turbo-method=delete]", workflow_run_path(workflow, second)
    assert_select "[popover] a[href^=?][data-turbo-method=delete]", workflow_run_path(workflow, first), count: 0

    post run_workflow_url(workflow, account: admin.id, run: second.id), params: { node_id: folder.id }
    assert_redirected_to workflow_url(workflow, account: admin.id, run: second.id)
    assert_equal [ 1, 1 ], [ first, second ].map { it.step_runs.count }

    assert_no_difference -> { workflow.runs.count } do
      delete workflow_run_url(workflow, first, account: admin.id)
    end
    assert_redirected_to workflow_url(workflow, account: admin.id, run: first.id)

    first.step_runs.sole.update!(status: "failed")
    assert_difference -> { workflow.runs.count } => -1, -> { TransformationRun.count } => -1, -> { LibraryMedia.count } => 0 do
      delete workflow_run_url(workflow, first, account: admin.id)
    end
    assert_redirected_to workflow_url(workflow, account: admin.id, run: second.id)
  end

  test "alt-dragging a step copies it with its own transformation and no connections" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Copy")
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation: transformations(:cinematic).dup)
    workflow.edges.create!(from: folder, to: step)

    get workflow_url(workflow, account: admin.id)
    assert_select "form[action^=?][data-workflow-target=copy] input[name=node_id]", copy_workflow_path(workflow)

    assert_difference -> { Transformation.count } do
      post copy_workflow_url(workflow, account: admin.id), params: { node_id: step.id, x: 400, y: 120 }
    end
    copy = workflow.nodes.reload.last
    assert_redirected_to workflow_url(workflow, account: admin.id, node: copy.id)
    assert_equal [ 400, 120 ], [ copy.x, copy.y ]
    assert_not_equal step.transformation, copy.transformation
    assert_equal step.transformation.attributes.slice("kind", "name", "body"), copy.transformation.attributes.slice("kind", "name", "body")
    assert_equal 1, workflow.edges.count
  end

  test "a folder's media is added from the inspector as a source that only feeds steps" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "One photo")
    media = admin.library_media.create!(kind: "photo", folder: folders(:interior))
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation: transformations(:cinematic))

    get workflow_url(workflow, account: admin.id, node: folder.id)
    assert_select "ul[aria-label=Media] li[draggable=true] button[form=workflow_add][name=?][value=?]", "workflow[nodes_attributes][0][library_media_id]", media.id.to_s

    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { library_media_id: media.id, x: 60, y: 300 } } } }
    source = workflow.nodes.reload.last
    assert_equal media, source.library_media

    connect = ->(from, to) { patch workflow_url(workflow, account: admin.id), params: { workflow: { edges_attributes: { "0" => { from_id: from.id, to_id: to.id } } } } }
    connect.(source, step)
    connect.(step, source)
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "A media only feeds transformations; nothing connects into it."
    assert_equal [ [ source.id, step.id ] ], workflow.edges.reload.map { [ it.from_id, it.to_id ] }

    get workflow_url(workflow, account: admin.id, node: source.id)
    assert_select "a[data-id=?][data-source][aria-current=true]", source.id.to_s
    assert_select "turbo-frame#inspector a[href^=?]", library_item_path(media), text: "Open in library"

    media.destroy!
    assert_equal [ folder, step ], workflow.nodes.reload.to_a
    assert_equal 0, workflow.edges.count
  end

  test "a sticky note is added, shows its Markdown on the canvas with links as text, and is edited in the inspector" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Noted")

    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { note: "Note", x: 60, y: 60 } } } }
    note = workflow.nodes.reload.sole
    patch workflow_url(workflow, account: admin.id), params: { workflow: { nodes_attributes: { "0" => { id: note.id, note: "## Why\n**Crop** first, see [docs](https://example.com)", color: "rose" } } } }
    assert_equal [ "## Why", "rose" ], [ note.reload.label, note.color ]

    get workflow_url(workflow, account: admin.id, node: note.id)
    assert_select "a[data-id=?][data-note][aria-current=true]", note.id.to_s do
      assert_select "div.bg-rose-50 h2", "Why"
      assert_select "strong", "Crop"
      assert_select "div a", count: 0
      assert_select "[data-flow-handle]", count: 0
    end
    assert_select "turbo-frame#inspector textarea[name=?]", "workflow[nodes_attributes][0][note]"
    assert_select "turbo-frame#inspector input[type=radio][value=rose][checked]"
  end
end
