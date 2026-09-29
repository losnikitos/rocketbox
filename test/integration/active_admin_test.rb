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
    assert_select "td.col-media video[src*='clip.mp4']"
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

  test "workflow runs and steps are linked from the post page and open in admin" do
    sign_in_as(users(:admin_user))
    user = users(:lazaro_nixon)
    media = LibraryMedia.create!(kind: "photo", user:)
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
    post = user.smm_posts.create!(recipe: recipes(:cinematic), status: "draft", smm_post_media_items: [ SmmPostMediaItem.new(library_media: media) ])
    run = WorkflowRun.create!(smm_post: post, workflow: "CinematicShopReel")
    step = run.workflow_steps.create!(key: "video")

    get "/app/instagram/posts/#{post.id}?account=#{user.id}", headers: @ua
    assert_response :success
    assert_select "article#video a[href^='/admin/workflow_steps/#{step.id}']"
    get "/admin/workflow_runs/#{run.id}", headers: @ua
    assert_select "a[href='/admin/workflow_steps/#{step.id}']", text: "video"
    get "/admin/workflow_steps/#{step.id}", headers: @ua
    assert_response :success
    assert_match "AiVideo", response.body
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
