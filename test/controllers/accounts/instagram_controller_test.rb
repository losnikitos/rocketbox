# frozen_string_literal: true

require "test_helper"

class Accounts::InstagramControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "sends an instagram connect link to whatsapp" do
    @user.update!(whatsapp_phone: "15551234567")
    sent = []
    original = WhatsappCloud.method(:send_cta_url)
    WhatsappCloud.define_singleton_method(:send_cta_url) { |**args| sent << args }

    get instagram_profile_url
    assert_select "[aria-label=?]", "QR code to connect Instagram"
    assert_select "form[action=?] button", instagram_profile_link_path, text: "Send link to WhatsApp"
    assert_select "a[href=?]", profile_instagram_authorize_path, text: "Connect here instead"

    post instagram_profile_link_url
    assert_redirected_to instagram_profile_url
    assert_equal "Link sent to +15551234567", flash[:notice]
    assert_equal "Connect Instagram", sent.sole[:display_text]
    assert_equal "15551234567", sent.sole[:to]
    assert_match(/[?&]to=instagram(?:&|\z)/, sent.sole[:url])
  ensure
    WhatsappCloud.define_singleton_method(:send_cta_url, original) if original
  end

  test "instagram connect link requires a whatsapp phone" do
    post instagram_profile_link_url

    assert_redirected_to instagram_profile_url
    assert_equal "Connect WhatsApp first.", flash[:alert]
  end

  test "shows connect until authorized, then fetch info" do
    get instagram_profile_url
    assert_response :success
    assert_select "h1", "Your profile"
    assert_select "[aria-label=?]", "QR code to connect Instagram"
    assert_select "form[action=?] button", instagram_profile_link_path, text: "Send link to WhatsApp"
    assert_select "a[href=?]", profile_instagram_authorize_path, text: "Connect here instead"
    assert_select "form[action=?]", profile_instagram_refresh_path, count: 0

    @user.update!(instagram_user_id: "1", instagram_access_token: "t")
    get instagram_profile_url
    assert_select "a[href=?]", profile_instagram_authorize_path, count: 0
    assert_select "p", text: "No profile info fetched yet."
    assert_select "form[action=?] button[aria-label=?]", profile_instagram_refresh_path, "Fetch info"
  end

  test "fetch info refreshes instagram profile and avatar" do
    @user.update!(instagram_user_id: "1", instagram_access_token: "t")
    stub_instagram_oauth { post profile_instagram_refresh_url }

    assert_redirected_to instagram_profile_url
    @user.reload
    assert_equal "ig-user", @user.instagram_user_id
    assert_equal({ "user_id" => "ig-user", "username" => "fadehouse", "followers_count" => 624 }, @user.instagram_profile)
    assert @user.instagram_avatar.attached?
  end

  test "disconnect clears instagram credentials" do
    @user.update!(instagram_user_id: "1", instagram_access_token: "t", instagram_profile: { "username" => "fadehouse" })
    get instagram_profile_url
    assert_select "form[action=?] button", instagram_profile_path, text: "Disconnect"

    delete instagram_profile_url

    assert_redirected_to instagram_profile_url
    assert_not @user.reload.instagram_authorized?
    assert_nil @user.instagram_profile
  end

  test "instagram oauth callback stores credentials" do
    stub_instagram_oauth do
      get profile_instagram_authorize_url
      assert_match %r{\Ahttps://www\.instagram\.com/oauth/authorize\?}, response.location
      state = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")

      get profile_instagram_callback_url, params: { code: "abc", state: }
    end

    assert_redirected_to instagram_profile_url
    assert_equal [ "ig-user", "fadehouse", "long-token-abc" ],
      @user.reload.values_at(:instagram_user_id, :instagram_username, :instagram_access_token)

    follow_redirect!
    assert_select "[data-just-authorized]"
    assert_select "[data-just-authorized] p", text: "Authorized"
    assert_select "[data-just-authorized] p", text: "You can close this page now"
    assert_select "a[href=?]", "https://www.instagram.com/fadehouse", text: "fadehouse"
    assert_select "li", text: "624 followers"

    get instagram_profile_url
    assert_select "[data-just-authorized]", count: 0
  end

  test "admin's instagram redirect_uri skips the account param and matches on exchange" do
    admin = sign_in_as(users(:admin_user))
    query = exchanged = nil
    stub_instagram_oauth do
      InstagramOauth.define_singleton_method(:exchange) { |code:, redirect_uri:| exchanged = redirect_uri; "t" }
      get profile_instagram_authorize_url(account: admin.id)
      query = Rack::Utils.parse_query(URI.parse(response.location).query)
      get profile_instagram_callback_url(account: admin.id), params: { code: "abc", state: query["state"] }
    end

    assert_equal "http://www.example.com/app/profile/instagram/callback", query["redirect_uri"]
    assert_equal query["redirect_uri"], exchanged
  end

  test "instagram oauth callback rejects bad state" do
    stub_instagram_oauth do
      get profile_instagram_authorize_url
      get profile_instagram_callback_url, params: { code: "abc", state: "nope" }
    end

    assert_redirected_to instagram_profile_url
    assert_nil @user.reload.instagram_access_token
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
