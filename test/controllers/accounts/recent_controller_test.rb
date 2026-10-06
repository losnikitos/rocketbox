# frozen_string_literal: true

require "test_helper"

class Accounts::RecentControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "app opens recent media newest first, 20 at a time, lazily loading older ones" do
    media = 21.times.map { |i| photo(i.even? ? folders(:inbox) : folders(:interior)) }
    oldest, last_shown, newest = media.first, media.second, media.last

    get app_url
    assert_redirected_to recent_url

    get recent_url
    assert_response :success
    assert_select "h1", "Recent"
    assert_select "[aria-label='Folder tree'] a[href=?][aria-current=page]", recent_path, text: /Recent/
    assert_select "ul[aria-label='Recent media'] > li", 20
    assert_select "ul[aria-label='Recent media'] > li:first-child #recent-media-#{newest.id}"
    assert_select "#recent-media-#{oldest.id}", count: 0
    assert_select "turbo-frame[loading=lazy][src=?]", recent_path(before: last_shown.id)

    get recent_url(before: last_shown.id), headers: { "Turbo-Frame" => "recent-#{last_shown.id}" }
    assert_response :success
    assert_select "turbo-frame#recent-#{last_shown.id} #recent-media-#{oldest.id}"
    assert_select "[id^=recent-media-]", 1
    assert_select "turbo-frame[loading=lazy]", count: 0
  end

  private

    def photo(folder)
      LibraryMedia.create!(kind: "photo", folder:, user: @user, file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    end
end
