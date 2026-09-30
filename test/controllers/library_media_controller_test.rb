# frozen_string_literal: true

require "test_helper"

class LibraryMediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    @media = LibraryMedia.create!(
      telegram_file_id: "f-remove",
      telegram_file_unique_id: "u-remove-ctrl",
      kind: "photo",
      user: @admin
    )
    @media.file.attach(io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg")
  end

  test "owner deletes media and posts made from it stay" do
    user = sign_in_as(users(:lazaro_nixon))
    media = user.library_media.create!(kind: "photo")
    media.file.attach(io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg")
    post = user.smm_posts.create!(recipe: recipes(:cinematic), smm_post_media_items: [ SmmPostMediaItem.new(library_media: media) ])

    assert_difference -> { LibraryMedia.count } => -1, -> { SmmPostMediaItem.count } => -1, -> { SmmPost.count } => 0 do
      delete library_media_url(media)
    end

    assert_redirected_to library_uploads_url
    assert_equal "Media deleted.", flash[:notice]
    assert_empty post.reload.library_media
    post.mark_ready!
  end

  test "applies a recipe that fits the media type" do
    @media.update!(media_type: "interior")

    assert_difference -> { Generation.count } => 1, -> { WorkflowRun.count } => 1, -> { LibraryMedia.photobank.count } => 1, -> { SmmPost.count } => 0 do
      post apply_recipe_library_media_url(@media, recipe_id: recipes(:cinematic).id)
    end
    assert_redirected_to %r{/library/uploads/#{@media.id}\b}
    generation = @media.generations.sole
    assert_equal recipes(:cinematic), generation.recipe
    assert_equal "running", generation.status

    run = generation.workflow_run
    post stop_library_media_url(generation.generated_media)
    assert_equal "stopped", run.reload.status

    run.step("photos").update!(status: "running")
    run.fail!("boom")
    post rerun_library_media_url(generation.generated_media, key: "photos")
    assert_redirected_to %r{/library/uploads/#{generation.generated_media.id}\b}
    assert_equal "running", run.reload.status
    assert_equal "pending", run.step("photos").status

    @media.update!(media_type: "exterior")
    assert_no_difference -> { Generation.count } do
      post apply_recipe_library_media_url(@media, recipe_id: recipes(:cinematic).id)
    end
    assert_equal "That recipe doesn't fit this media.", flash[:alert]
  end

  test "cannot delete another account's media" do
    sign_in_as(users(:lazaro_nixon))

    assert_no_difference -> { LibraryMedia.count } do
      delete library_media_url(@media)
    end

    assert_equal "Media not found.", flash[:alert]
  end

  test "shows alert when media not found" do
    delete library_media_url(id: 0)

    assert_redirected_to library_uploads_url(account: @admin.id)
    assert_equal "Media not found.", flash[:alert]
  end

  test "sets and clears media type" do
    patch library_media_url(@media), params: { library_media: { media_type: "logo" } }
    assert_redirected_to library_upload_url(@media, account: @admin.id)
    assert_equal "logo", @media.reload.media_type

    patch library_media_url(@media), params: { library_media: { media_type: "" } }
    assert_nil @media.reload.media_type

    patch library_media_url(@media), params: { library_media: { media_type: "bogus" } }
    assert_nil @media.reload.media_type
    assert flash[:alert].present?
  end

  test "bulk sets media type within the account only" do
    other = LibraryMedia.create!(kind: "photo", user: @admin)
    foreign = LibraryMedia.create!(kind: "photo", user: users(:lazaro_nixon))

    patch bulk_update_library_media_index_url, params: { media_type: "interior", ids: [ @media.id, other.id, foreign.id ] }
    assert_redirected_to library_uploads_url(account: @admin.id)
    assert_equal "Media type saved for 2 files.", flash[:notice]
    assert_equal %w[interior interior], [ @media.reload.media_type, other.reload.media_type ]
    assert_nil foreign.reload.media_type

    patch bulk_update_library_media_index_url, params: { media_type: "", ids: [ @media.id ] }
    assert_nil @media.reload.media_type

    patch bulk_update_library_media_index_url, params: { media_type: "bogus", ids: [ other.id ] }
    assert_equal "interior", other.reload.media_type
    assert_equal "Unknown media type.", flash[:alert]
  end

  test "applies extracted business card fields and logo to the account" do
    @admin.update!(business_name: "Old name", address: "1 Old St")
    @media.update!(media_type: "business_card", extracted_info: {
      "status" => "done",
      "has_logo" => true,
      "fields" => { "business_name" => " Fade Co ", "phone" => "+1 555 0100", "website" => "https://fade.co", "address" => nil, "person_name" => "" }
    })
    @media.extracted_logo.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png")

    patch apply_extraction_library_media_url(@media)

    assert_redirected_to library_upload_url(@media, account: @admin.id)
    @admin.reload
    assert_equal "Fade Co", @admin.business_name
    assert_equal "+1 555 0100", @admin.phone
    assert_equal "https://fade.co", @admin.homepage_url
    assert_equal "1 Old St", @admin.address
    assert_equal @media.extracted_logo.checksum, @admin.logo.checksum

    post extract_library_media_url(@media)
    assert @admin.reload.logo.attached?, "re-extracting must not purge the applied logo"
  end

  test "extract enqueues the job for business cards only" do
    post extract_library_media_url(@media)
    assert_redirected_to library_upload_url(@media, account: @admin.id)
    assert_nil @media.reload.extracted_info

    @media.update!(media_type: "business_card")
    assert_enqueued_with(job: ExtractBusinessCardJob, args: [ @media.id ]) do
      post extract_library_media_url(@media)
    end
    assert_equal "pending", @media.reload.extraction_status
  end

  test "uploads photo files into the library" do
    user = sign_in_as(users(:lazaro_nixon))
    file = fixture_file_upload("logo.png", "image/png")

    assert_difference -> { user.library_media.count }, 1 do
      post library_media_index_url, params: { files: [ file ] }
    end

    media = user.library_media.order(:id).last
    assert media.file.attached?
    assert_equal "photo", media.kind
    assert_redirected_to library_uploads_url
    assert_equal "Uploaded 1 file.", flash[:notice]
  end

  test "uploads into the photobank and deletes back to it" do
    user = sign_in_as(users(:lazaro_nixon))

    post library_media_index_url, params: { collection: "photobank", files: [ fixture_file_upload("logo.png", "image/png") ] }
    media = user.library_media.order(:id).last
    assert media.photobank?
    assert_redirected_to library_photobank_url

    delete library_media_url(media)
    assert_redirected_to library_photobank_url

    post library_media_index_url, params: { collection: "bogus", files: [ fixture_file_upload("logo.png", "image/png") ] }
    assert user.library_media.order(:id).last.inbox?
  end

  test "rejects empty upload" do
    sign_in_as(users(:lazaro_nixon))

    assert_no_difference -> { LibraryMedia.count } do
      post library_media_index_url, params: { files: [] }
    end

    assert_redirected_to library_uploads_url
    assert_equal "Drop a photo or video to upload.", flash[:alert]
  end
end
