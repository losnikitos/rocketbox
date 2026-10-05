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
    post = user.smm_posts.create!(smm_post_media_items: [ SmmPostMediaItem.new(library_media: media) ])

    assert_difference -> { LibraryMedia.count } => -1, -> { SmmPostMediaItem.count } => -1, -> { SmmPost.count } => 0 do
      delete library_media_url(media)
    end

    assert_redirected_to library_uploads_url
    assert_equal "Media deleted.", flash[:notice]
    assert_empty post.reload.library_media
    post.update!(status: "ready")
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

  test "sets and clears tag" do
    patch library_media_url(@media), params: { library_media: { tag_id: tags(:logo).id } }
    assert_redirected_to library_upload_url(@media, account: @admin.id)
    assert_equal tags(:logo), @media.reload.tag

    patch library_media_url(@media), params: { library_media: { tag_id: "" } }
    assert_nil @media.reload.tag

    patch library_media_url(@media), params: { library_media: { tag_id: 0 } }
    assert_nil @media.reload.tag
    assert flash[:alert].present?
  end

  test "applies extracted business card fields and logo to the account" do
    @admin.update!(business_name: "Old name", address: "1 Old St")
    @media.update!(tag: tags(:business_card), extracted_info: {
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

    @media.update!(tag: tags(:business_card))
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

  test "upload into a tag-filtered view gets that tag" do
    user = sign_in_as(users(:lazaro_nixon))

    post library_media_index_url, params: { tag: tags(:interior).slug, files: [ fixture_file_upload("logo.png", "image/png") ] }

    assert_equal tags(:interior), user.library_media.order(:id).last.tag
    assert_redirected_to library_uploads_url(tag: tags(:interior).slug)
  end

  test "converts HEIC uploads to JPEG" do
    user = sign_in_as(users(:lazaro_nixon))

    post library_media_index_url, params: { files: [ fixture_file_upload("photo.heic", "application/octet-stream") ] }

    media = user.library_media.order(:id).last
    assert_equal "photo", media.kind
    assert_equal "image/jpeg", media.file.content_type
    assert_equal "photo.jpg", media.file.filename.to_s
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

  test "upload dropped onto a group attaches to its source" do
    user = sign_in_as(users(:lazaro_nixon))
    source = user.library_media.create!(kind: "photo", collection: "photobank", tag: tags(:interior))

    post library_media_index_url, params: { collection: "photobank", source_id: source.id, files: [ fixture_file_upload("logo.png", "image/png") ] }

    media = user.library_media.order(:id).last
    assert_equal source, media.source_media
    assert media.origin.complete?
    assert_nil media.origin.prompt
    assert_equal tags(:interior), media.tag
    assert_redirected_to library_photobank_url

    get library_photobank_media_url(media)
    assert_response :success

    assert_no_difference -> { LibraryMedia.count } do
      post library_media_index_url, params: { source_id: @media.id, files: [ fixture_file_upload("logo.png", "image/png") ] }
    end
    assert_response :not_found
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
