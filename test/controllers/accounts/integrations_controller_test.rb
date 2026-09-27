# frozen_string_literal: true

require "test_helper"

class Accounts::IntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show integrations" do
    get integrations_url
    assert_response :success
    assert_select "h1", "Integrations"
  end

  test "should update integrations" do
    patch integrations_url, params: {
      user: {
        instagram_user_id: "28810616161875865",
        instagram_access_token: "ig-token-example",
        telegram_user_id: 90504516
      }
    }

    assert_redirected_to integrations_url
    assert_equal "Account updated.", flash[:notice]

    @user.reload
    assert_equal "28810616161875865", @user.instagram_user_id
    assert_equal "ig-token-example", @user.instagram_access_token
    assert_equal 90504516, @user.telegram_user_id
  end

  test "shows authorize button until instagram is authorized" do
    get integrations_url
    assert_select "a[href=?]", profile_instagram_authorize_path, text: "Authorize"
    assert_select "button[form=instagram-refresh][disabled]", text: "Fetch info"

    @user.update!(instagram_user_id: "1", instagram_access_token: "t")
    get integrations_url
    assert_select "a[href=?]", profile_instagram_authorize_path, count: 0
    assert_select "span", text: /Authorized/
    assert_select "button[form=instagram-refresh]:not([disabled])", text: "Fetch info"
  end

  test "fetch info refreshes instagram profile and avatar" do
    @user.update!(instagram_user_id: "1", instagram_access_token: "t")
    stub_instagram_oauth { post profile_instagram_refresh_url }

    assert_redirected_to integrations_url
    @user.reload
    assert_equal "ig-user", @user.instagram_user_id
    assert_equal({ "user_id" => "ig-user", "username" => "fadehouse", "followers_count" => 624 }, @user.instagram_profile)
    assert @user.instagram_avatar.attached?
  end

  test "instagram oauth callback stores credentials" do
    stub_instagram_oauth do
      get profile_instagram_authorize_url
      assert_match %r{\Ahttps://www\.instagram\.com/oauth/authorize\?}, response.location
      state = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")

      get profile_instagram_callback_url, params: { code: "abc", state: }
    end

    assert_redirected_to integrations_url
    assert_equal [ "ig-user", "fadehouse", "long-token-abc" ],
      @user.reload.values_at(:instagram_user_id, :instagram_username, :instagram_access_token)

    get integrations_url
    assert_select "a[href=?]", "https://www.instagram.com/fadehouse", text: "@fadehouse"
    assert_select "details dt", text: "Followers count"
    assert_select "details dd", text: "624"
  end

  test "instagram oauth callback rejects bad state" do
    stub_instagram_oauth do
      get profile_instagram_authorize_url
      get profile_instagram_callback_url, params: { code: "abc", state: "nope" }
    end

    assert_redirected_to integrations_url
    assert_nil @user.reload.instagram_access_token
  end

  test "autosave update returns ok without redirect" do
    patch integrations_url,
      params: { user: { whatsapp_phone: "15551234567" } },
      headers: { "X-Autosave" => "1", "Accept" => "application/json" }

    assert_response :ok
    assert_equal "15551234567", @user.reload.whatsapp_phone
  end

  test "backfills orphan library media when telegram_user_id is saved" do
    orphan = LibraryMedia.create!(
      telegram_file_id: "file-1",
      telegram_file_unique_id: "unique-1",
      chat_id: 90504516,
      from_id: 90504516,
      kind: "photo"
    )

    patch integrations_url, params: { user: { telegram_user_id: 90504516 } }

    assert_redirected_to integrations_url
    assert_equal @user.id, orphan.reload.user_id
  end

  test "backfills orphan library media when whatsapp_phone is saved" do
    orphan = LibraryMedia.create!(
      whatsapp_media_id: "wa-media-1",
      whatsapp_from: "15551234567",
      kind: "photo"
    )

    patch integrations_url, params: { user: { whatsapp_phone: "+1 (555) 123-4567" } }

    assert_redirected_to integrations_url
    @user.reload
    assert_equal "15551234567", @user.whatsapp_phone
    assert_equal @user.id, orphan.reload.user_id
  end

  private

    # Minitest 6 dropped Object#stub; override the singletons and restore them.
    def stub_instagram_oauth
      originals = %i[app_id exchange profile picture].index_with { InstagramOauth.method(_1) }
      InstagramOauth.define_singleton_method(:app_id) { "app-1" }
      InstagramOauth.define_singleton_method(:exchange) { |code:, redirect_uri:| "long-token-#{code}" }
      InstagramOauth.define_singleton_method(:profile) do |_token|
        { "user_id" => "ig-user", "username" => "fadehouse", "followers_count" => 624, "profile_picture_url" => "https://cdn.example/p.jpg" }
      end
      InstagramOauth.define_singleton_method(:picture) { |_url| { io: StringIO.new("jpeg"), content_type: "image/jpeg" } }
      yield
    ensure
      originals.each { |name, method| InstagramOauth.define_singleton_method(name, method) }
    end
end
