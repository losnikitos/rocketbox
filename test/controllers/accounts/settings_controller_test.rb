# frozen_string_literal: true

require "test_helper"

class Accounts::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "autosave update returns ok without redirect" do
    patch profile_settings_url,
      params: { user: { name: "Alan" } },
      headers: { "X-Autosave" => "1", "Accept" => "application/json" }

    assert_response :ok
    assert_equal "Alan", @user.reload.name
  end

  test "whatsapp phone can't be set from the dashboard" do
    patch profile_settings_url, params: { user: { whatsapp_phone: "15551234567" } }

    assert_nil @user.reload.whatsapp_phone
  end

  test "updates name" do
    patch profile_settings_url, params: { user: { name: "Alan" } }

    assert_redirected_to profile_settings_url
    assert_equal "Alan", @user.reload.name
  end

  test "changing email unverifies and sends verification" do
    assert_enqueued_email_with UserMailer, :email_verification, params: { user: @user } do
      patch profile_settings_url,
        params: { user: { email: "New@Example.com" } },
        headers: { "X-Autosave" => "1", "Accept" => "application/json" }
    end

    assert_response :ok
    @user.reload
    assert_equal "new@example.com", @user.email
    assert_not @user.verified?
  end

  test "sets a password" do
    patch profile_settings_url, params: { user: { password: "correct horse" } }

    assert_redirected_to profile_settings_url
    assert @user.reload.authenticate("correct horse")
  end

  test "rejects a short password" do
    patch profile_settings_url, params: { user: { password: "short" } }

    assert_response :unprocessable_entity
    assert_nil @user.reload.password_digest
  end

  test "user can delete their own account" do
    assert_difference("User.count", -1) do
      delete profile_settings_url
    end

    assert_redirected_to sign_in_url
    assert_not User.exists?(@user.id)
  end

  test "admin can delete another account" do
    sign_in_as(users(:admin_user))
    customer = users(:lazaro_nixon)

    assert_difference("User.count", -1) do
      delete profile_settings_url(account: customer.id)
    end

    assert_redirected_to onboarding_url(account: users(:admin_user).id)
    assert_not User.exists?(customer.id)
  end

  test "reset clears usage and keeps the business and logo" do
    @user.update!(
      business_name: "Lazaro Cuts",
      whatsapp_phone: "15551234567",
      whatsapp_pending_question: "email",
      whatsapp_login_at: Time.current,
      instagram_user_id: "ig",
      instagram_access_token: "token",
      instagram_profile: { "username" => "lazaro" },
      telegram_user_id: 99
    )
    file = { io: StringIO.new("img"), filename: "cut.jpg", content_type: "image/jpeg" }
    inbox = @user.library_media.create!(kind: "photo", folder: folders(:inbox), file:)
    ready = @user.library_media.create!(kind: "photo", folder: folders(:ready), file: file.merge(io: StringIO.new("reel")))
    logo = @user.library_media.create!(kind: "photo", folder: folders(:photobank_logo), file: file.merge(io: StringIO.new("logo"), filename: "logo.png", content_type: "image/png"))
    other = users(:admin_user).library_media.create!(kind: "photo", folder: folders(:inbox), file: file.merge(io: StringIO.new("other")))
    workflow = Workflow.create!(name: "Haircut reel")
    node = workflow.nodes.create!(library_media: inbox)
    run = workflow.runs.create!(status: "started")
    run.step_runs.create!(result: ready, status: "complete")
    @user.incoming_messages.create!(channel: "whatsapp", sender: "15551234567", payload: { "x" => 1 }, body: "hi")
    IncomingMessage.create!(channel: "whatsapp", sender: "15551234567", payload: { "x" => 1 }, body: "orphan")
    @user.outgoing_messages.create!(channel: "whatsapp", recipient: "15551234567", payload: { "to" => "1" }, body: "hello")
    @user.jobs.create!
    rubric = @user.rubrics.create!(name: "Daily", schedule: "every day at 9am", folder: folders(:ready))
    rubric.posts.create!(library_media: ready, scheduled_at: Time.current)
    prompt = @user.prompts.create!(name: "Shot", folder: folders(:prompts_shots), body: "a cut")
    @user.create_chat!.messages.create!(role: "user", content: "hi")

    assert_no_difference("User.count") do
      post reset_profile_settings_url
    end

    assert_redirected_to profile_settings_url
    @user.reload
    assert_equal "Lazaro Cuts", @user.business_name
    assert_nil @user.whatsapp_phone
    assert_nil @user.whatsapp_pending_question
    assert_nil @user.whatsapp_login_at
    assert_nil @user.instagram_user_id
    assert_nil @user.instagram_access_token
    assert_nil @user.instagram_profile
    assert_nil @user.telegram_user_id
    assert LibraryMedia.exists?(logo.id)
    assert_not LibraryMedia.exists?(inbox.id)
    assert_not LibraryMedia.exists?(ready.id)
    assert LibraryMedia.exists?(other.id)
    assert_not WorkflowRun.exists?(run.id)
    assert Workflow.exists?(workflow.id)
    assert_nil node.reload.library_media_id
    assert_empty @user.incoming_messages
    assert_empty IncomingMessage.where(sender: "15551234567")
    assert_empty @user.outgoing_messages
    assert_empty @user.jobs
    assert_empty @user.prompts
    assert_not Prompt.exists?(prompt.id)
    assert Rubric.exists?(rubric.id)
    assert_empty rubric.posts.reload
    assert_nil @user.reload.chat
  end

  test "admin cannot delete the signed-in account" do
    admin = sign_in_as(users(:admin_user))

    assert_no_difference("User.count") do
      delete profile_settings_url(account: admin.id)
    end

    assert_redirected_to profile_settings_url(account: admin.id)
    assert User.exists?(admin.id)
  end
end
