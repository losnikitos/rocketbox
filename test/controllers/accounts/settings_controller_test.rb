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
end
