require "test_helper"

class ActiveAdminTest < ActionDispatch::IntegrationTest
  setup do
    @ua = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" }
  end

  test "anon redirects to sign in" do
    get "/admin", headers: @ua
    assert_redirected_to sign_in_path
  end

  test "non-admin redirected to root" do
    sign_in_as(users(:lazaro_nixon))
    get "/admin", headers: @ua
    assert_redirected_to root_path
  end

  test "admin can open dashboard" do
    sign_in_as(users(:admin_user))
    get "/admin", headers: @ua
    assert_response :success
    assert_match(/Dashboard/i, response.body)
    assert_match(/active_admin/, response.body)
  end

  test "admin can open rubyllm resources" do
    sign_in_as(users(:admin_user))
    %w[chats messages models tool_calls usages batches].each do |resource|
      get "/admin/#{resource}", headers: @ua
      assert_response :success, "expected /admin/#{resource} to load"
    end
  end

  test "admin can open chat with messages" do
    sign_in_as(users(:admin_user))
    model = RubyLLM::ActiveRecord::Model.create!(model_id: "admin-test", name: "Admin Test", provider: "test")
    chat = Chat.create!(model: model)
    message = chat.messages.create!(role: "user", content: "hello from test")
    get "/admin/chats/#{chat.id}", headers: @ua
    assert_response :success
    assert_match(/hello from test/, response.body)
    get "/admin/messages/#{message.id}", headers: @ua
    assert_response :success
  end

  test "incoming messages index shows media previews" do
    sign_in_as(users(:admin_user))
    message = IncomingMessage.create!(channel: "whatsapp", payload: { "id" => "1" })
    message.attachments.attach(io: StringIO.new("img"), filename: "pic.jpg", content_type: "image/jpeg")
    message.attachments.attach(io: StringIO.new("vid"), filename: "clip.mp4", content_type: "video/mp4")
    get "/admin/incoming_messages", headers: @ua
    assert_response :success
    assert_select "td.col-media img[src*='pic.jpg']"
    assert_select "td.col-media a[href*='clip.mp4'] img[src*='/representations/']"
  end

  test "user page shows incoming and outgoing messages in order" do
    sign_in_as(users(:admin_user))
    user = users(:lazaro_nixon)
    incoming = user.incoming_messages.create!(channel: "whatsapp", body: "first in", payload: { "id" => "1" }, created_at: 2.minutes.ago)
    incoming.attachments.attach(io: StringIO.new("img"), filename: "cut.jpg", content_type: "image/jpeg")
    user.outgoing_messages.create!(channel: "whatsapp", body: "then out", payload: { "to" => "1" }, created_at: 1.minute.ago)
    get "/admin/users/#{user.id}", headers: @ua
    assert_response :success
    assert_match(/first in.*then out/m, response.body)
    assert_select "td.col-media img[src*='cut.jpg']"
  end

  test "admin can list and rename folders" do
    sign_in_as(users(:admin_user))
    get "/admin/folders", headers: @ua
    assert_response :success
    assert_match "Business card", response.body

    patch "/admin/folders/#{folders(:misc).id}", params: { folder: { name: "Other" } }, headers: @ua
    assert_equal [ "Other", "misc" ], folders(:misc).reload.values_at(:name, :slug)

    post "/admin/folders", params: { folder: { name: "Before after", parent_id: folders(:photobank).id } }, headers: @ua
    assert_equal "before-after", folders(:photobank).children.find_by!(name: "Before after").slug
  end

  test "transformation run is linked from its media page and opens in admin" do
    admin = sign_in_as(users(:admin_user))
    source = LibraryMedia.create!(kind: "photo", folder: folders(:interior), user: admin)
    source.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
    generation = transformations(:cinematic).run!(media: [ source ], folder: folders(:photobank_interior))
    generation.update!(status: "failed", error: "content policy")

    get "/app/library/media/#{generation.generated_media.id}?account=#{admin.id}", headers: @ua
    assert_response :success
    assert_select "a[href^='/admin/transformation_runs/#{generation.id}']"
    get "/admin/transformation_runs/#{generation.id}", headers: @ua
    assert_response :success
    assert_match "content policy", response.body
    get "/admin/transformation_runs", headers: @ua
    assert_response :success
  end

  test "admin lists and opens transformations, linked to their workflow steps" do
    sign_in_as(users(:admin_user))
    workflow = create_workflow("Stored", input: folders(:interior), transformation: transformations(:cinematic))
    step = workflow.nodes.find(&:step?)
    get "/admin/transformations", headers: @ua
    assert_response :success
    assert_select "td.col-workflows a", text: "Stored"
    get "/admin/transformations/#{step.transformation_id}", headers: @ua
    assert_response :success
    assert_match transformations(:cinematic).body, response.body
    assert_select "a[href='/app/workflows/stored?node=#{step.id}']", text: "Stored"
  end

  test "workflow links to admin, which shows its nodes, edges and runs" do
    admin = sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Stored")
    folder = workflow.nodes.create!(folder: folders(:interior), x: 12, y: 34)
    step = workflow.nodes.create!(transformation: transformations(:cinematic))
    workflow.edges.create!(from: folder, to: step)
    workflow.latest_run

    get "/app/workflows/stored?account=#{admin.id}", headers: @ua
    assert_select "header a[href^='/admin/workflows/stored']"
    get "/admin/workflows", headers: @ua
    assert_response :success
    get "/admin/workflows/stored", headers: @ua
    assert_response :success
    assert_select "td", text: "##{folder.id} #{folder.label}"
    assert_select "a[href='/admin/transformations/#{step.transformation_id}']"
    assert_select "td", text: "Run 1"
  end

  test "admin edits a workflow's name and autorun" do
    sign_in_as(users(:admin_user))
    workflow = Workflow.create!(name: "Stored")

    get "/admin/workflows/stored/edit", headers: @ua
    assert_response :success
    patch "/admin/workflows/stored", params: { workflow: { name: "Renamed", autorun: "1" } }, headers: @ua
    assert_redirected_to "/admin/workflows/renamed"
    assert_equal [ "Renamed", true ], workflow.reload.values_at(:name, :autorun)
  end

  test "admin edits a workflow run's name, status and error" do
    sign_in_as(users(:admin_user))
    run = Workflow.create!(name: "Stored").runs.create!(status: "started", error: "Boom")

    get "/admin/workflow_runs/#{run.id}/edit", headers: @ua
    assert_response :success
    patch "/admin/workflow_runs/#{run.id}", params: { workflow_run: { name: "Retry", status: "draft", error: "" } }, headers: @ua
    assert_redirected_to "/admin/workflow_runs/#{run.id}"
    assert_equal [ "Retry", "draft", nil ], run.reload.values_at(:name, :status, :error)
  end

  test "admin manages tags and tags media" do
    admin = sign_in_as(users(:admin_user))
    Workflow.create!(name: "Tagged").nodes.create!(folder: folders(:ready), tag_ids: [ tags(:after).id ])
    post "/admin/tags", params: { tag: { name: "#Fresh" } }, headers: @ua
    assert_equal "fresh", Tag.last.name
    get "/admin/tags", headers: @ua
    assert_response :success
    assert_select "td.col-workflows a", text: "Tagged"

    media = LibraryMedia.create!(kind: "photo", folder: folders(:interior), user: admin)
    get "/admin/library_media/#{media.id}/edit", headers: @ua
    assert_response :success
    patch "/admin/library_media/#{media.id}", params: { library_media: { tag_ids: [ "", tags(:before).id ] } }, headers: @ua
    assert_equal [ tags(:before) ], media.reload.tags.to_a
  end

  test "admin can refresh models" do
    sign_in_as(users(:admin_user))
    with_model_refresh_stub(nil) do
      post "/admin/models/refresh", headers: @ua
    end
    assert_redirected_to "/admin/models"
    assert_match(/refreshed/i, flash[:notice].to_s)
  end

  test "admin sees alert when refresh fails" do
    sign_in_as(users(:admin_user))
    with_model_refresh_stub(RubyLLM::ModelRegistryError.new("boom")) do
      post "/admin/models/refresh", headers: @ua
    end
    assert_redirected_to "/admin/models"
    assert_match(/boom/, flash[:alert].to_s)
  end

  private

  # Minitest 6 dropped Object#stub; override the singleton and restore it.
  def with_model_refresh_stub(result)
    model_class = RubyLLM::ActiveRecord::Model
    original = model_class.method(:refresh)
    model_class.define_singleton_method(:refresh) { raise result if result.is_a?(Exception) }
    yield
  ensure
    model_class.define_singleton_method(:refresh, original)
  end
end
