# frozen_string_literal: true

require "test_helper"

class Accounts::LibraryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show library uploads" do
    get library_uploads_url
    assert_response :success
    assert_select "h1", "Inbox"
    assert_select "nav[aria-label='Primary']"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", library_uploads_path, text: "Inbox"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", library_uploads_path, text: "All 0"
    assert_select "nav[aria-label='Secondary'] label[for=?]", "library-upload-input", text: "Upload"
    assert_select "nav[aria-label='Secondary'] a", text: "Reels", count: 0
    assert_select "nav[aria-label='Primary'] a[href=?]", profile_settings_path, text: "Profile"
    assert_select "button[popovertarget='use-cases-menu']", count: 0
  end

  test "shows selectable story images without publish or improve" do
    media = LibraryMedia.create!(
      telegram_file_id: "f3",
      telegram_file_unique_id: "u3-library-btn",
      kind: "photo",
      user: @user
    )
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    get library_uploads_url
    assert_response :success
    assert_select "form[action=?]", new_instagram_post_path
    assert_select "input[data-library-select-target=?]", "checkbox"
    assert_select "form[action=?] select[name=media_type]", bulk_update_library_media_index_path
    assert_select "button", text: "Publish as Instagram story", count: 0
    assert_select "button", text: "Improve with AI", count: 0
  end

  test "filters uploads by media type tab" do
    card = LibraryMedia.create!(kind: "photo", media_type: "business_card", user: @user)
    card.file.attach(io: StringIO.new("img"), filename: "card.jpg", content_type: "image/jpeg")
    interior = LibraryMedia.create!(kind: "photo", media_type: "interior", user: @user)
    interior.file.attach(io: StringIO.new("img"), filename: "room.jpg", content_type: "image/jpeg")

    get library_uploads_url(type: "business_card")
    assert_response :success
    assert_select "a[href=?]", library_upload_path(card)
    assert_select "a[href=?]", library_upload_path(interior), count: 0
    assert_select "li span", text: "Business card"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", library_uploads_path(type: "business_card"), text: "Business Card 1"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='false']", library_uploads_path, text: "All 2"
    assert_select "nav[aria-label='Secondary'] a[href=?]", library_uploads_path(type: "logo"), text: "Logo 0"
  end

  test "source shows recipes and generated media; generated links back to its source" do
    source = LibraryMedia.create!(kind: "photo", media_type: "interior", user: @user)
    source.file.attach(io: StringIO.new("img"), filename: "room.jpg", content_type: "image/jpeg")
    generated = LibraryMedia.create!(kind: "photo", media_type: "interior", user: @user)
    generated.file.attach(io: StringIO.new("img"), filename: "film.jpg", content_type: "image/jpeg")
    source.generations.create!(recipe: recipes(:cinematic), generated_media: generated)
    failed = Generation.start!(source, recipes(:cinematic))
    get library_upload_url(failed.generated_media)
    assert_select "form[action=?] button", stop_library_media_path(failed.generated_media), text: /Stop/
    failed.workflow_run.step("photos").update!(status: "running")
    failed.workflow_run.fail!("content policy")

    get library_upload_url(source)
    assert_select "form[action=?]", apply_recipe_library_media_path(source, recipe_id: recipes(:cinematic).id)
    assert_select "form[action*=?]", "recipe_id=#{recipes(:before_after).id}", count: 0
    assert_select "#generated-heading + ul a[href=?]", library_upload_path(generated)
    assert_select "#generated-heading + ul a[href=?]", library_upload_path(failed.generated_media), text: /Generation failed/

    get library_upload_url(generated)
    assert_select "section a[href=?]", library_upload_path(source), text: /Cinematic shop reel/
    assert_select "#generated-heading", count: 0

    get library_upload_url(failed.generated_media)
    assert_select "#workflow-heading", text: "Cinematic shop reel"
    assert_select "section p", text: "content policy"
    assert_select "form[action=?]", stop_library_media_path(failed.generated_media), count: 0
    assert_select "article#photos form[action=?]", rerun_library_media_path(failed.generated_media, key: "photos")

    get library_photobank_url
    assert_select "a[href=?]", library_upload_path(failed.generated_media), text: /Generation failed/

    get library_uploads_url
    assert_select "[aria-label='Generated media'] a[href=?]", library_upload_path(generated), count: 1
  end

  test "reviews tab shows read-only media from active reviews" do
    @user.reviews.create!(source: "google", customer_name: "Ana", rating: 5,
      media: [ { io: file_fixture("logo.png").open, filename: "ana.png", content_type: "image/png" } ])
    @user.reviews.create!(source: "google", customer_name: "Old", rating: 5, archived_at: Time.current,
      media: [ { io: file_fixture("logo.png").open, filename: "old.png", content_type: "image/png" } ])

    get library_uploads_url(type: "reviews")
    assert_response :success
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", library_uploads_path(type: "reviews"), text: "Reviews 1"
    assert_select "nav[aria-label='Secondary'] a[href=?]", library_uploads_path, text: "All 0"
    assert_select "img[alt=?]", "Photo from Ana", count: 1
    assert_select "img[alt=?]", "Photo from Old", count: 0
    assert_select "input[data-library-select-target=?]", "checkbox", count: 0
  end

  test "tiles link to media show page with details panel" do
    media = LibraryMedia.create!(kind: "photo", user: @user)
    media.file.attach(io: StringIO.new("img"), filename: "cut.jpg", content_type: "image/jpeg")

    get library_uploads_url
    assert_select "a[href=?] img", library_upload_path(media)

    get library_upload_url(media)
    assert_response :success
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", library_uploads_path
    assert_select "img[src]"
    assert_select "aside dd", text: "cut.jpg"
  end

  test "photobank lists only curated media, apart from the inbox" do
    inbox = LibraryMedia.create!(kind: "photo", user: @user)
    inbox.file.attach(io: StringIO.new("img"), filename: "inbox.jpg", content_type: "image/jpeg")
    curated = LibraryMedia.create!(kind: "photo", collection: "photobank", media_type: "interior", user: @user)
    curated.file.attach(io: StringIO.new("img"), filename: "curated.jpg", content_type: "image/jpeg")

    get library_photobank_url
    assert_response :success
    assert_select "h1", "Photobank"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", library_photobank_path, text: "Photobank"
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", library_photobank_path, text: "All 1"
    assert_select "nav[aria-label='Secondary'] a[href=?]", library_photobank_path(type: "interior"), text: "Interior 1"
    assert_select "nav[aria-label='Secondary'] a", text: /Reviews/, count: 0
    assert_select "input[name=collection][value=photobank]"
    assert_select "a[href=?]", library_upload_path(curated)
    assert_select "a[href=?]", library_upload_path(inbox), count: 0

    get library_uploads_url
    assert_select "nav[aria-label='Secondary'] a[href=?]", library_uploads_path, text: "All 1"
    assert_select "a[href=?]", library_upload_path(curated), count: 0

    get library_upload_url(curated)
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", library_photobank_path
    assert_select "main a[href=?]", library_photobank_path, text: /Photobank/
  end

  test "cannot view another account's media" do
    media = LibraryMedia.create!(kind: "photo", user: users(:admin_user))

    get library_upload_url(media)
    assert_response :not_found
  end

  test "requires sign in" do
    delete session_url(@user.sessions.last)
    get library_uploads_url
    assert_redirected_to sign_in_url
  end

  test "admin sees admin and remove links on media" do
    admin = sign_in_as(users(:admin_user))
    media = LibraryMedia.create!(
      telegram_file_id: "f-admin",
      telegram_file_unique_id: "u-admin-library",
      kind: "photo",
      user: admin
    )
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    get library_uploads_url(account: admin.id)
    assert_response :success
    assert_select "[title='Admin actions']"
    assert_select "a[href=?]", admin_library_media_path(media, account: admin.id), text: "Admin"
    assert_select "a[href=?][data-turbo-method=?]", library_media_path(media, account: admin.id), "delete", text: "Remove"
  end

  test "non-admin does not see admin link menu" do
    media = LibraryMedia.create!(
      telegram_file_id: "f-user",
      telegram_file_unique_id: "u-user-library",
      kind: "photo",
      user: @user
    )
    media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")

    get library_uploads_url
    assert_response :success
    assert_select "[title='Admin actions']", count: 0
  end

  test "app root redirects to library uploads" do
    get "/app"
    assert_redirected_to "/app/library/uploads"
  end
end
