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

    assert_redirected_to library_folders_url("inbox")
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

    assert_redirected_to library_folders_url("inbox", account: @admin.id)
    assert_equal "Media not found.", flash[:alert]
  end

  test "moves media into any folder, across roots" do
    assert_equal folders(:inbox), @media.folder

    patch library_media_url(@media), params: { library_media: { folder_id: folders(:photobank_logo).id } }
    assert_redirected_to library_item_url(@media, account: @admin.id)
    assert_equal "Moved to Photobank / Logo.", flash[:notice]
    assert_equal folders(:photobank_logo), @media.reload.folder

    patch library_media_url(@media), params: { library_media: { folder_id: folders(:inbox).id } }
    assert_equal folders(:inbox), @media.reload.folder

    patch library_media_url(@media), params: { library_media: { folder_id: 0 } }
    assert_equal folders(:inbox), @media.reload.folder
    assert flash[:alert].present?
  end

  test "sets and clears tags, shown as #name pills on the media page" do
    patch library_media_url(@media), params: { library_media: { tag_ids: [ "", tags(:before).id ] } }
    assert_equal "Tags updated.", flash[:notice]
    assert_equal [ tags(:before) ], @media.reload.tags.to_a

    get library_item_url(@media, account: @admin.id)
    assert_select "aside section[aria-label=Tags] > span", text: "before" do
      assert_select "svg.text-orange-500"
    end

    patch library_media_url(@media), params: { library_media: { tag_ids: [ "" ] } }
    assert_empty @media.reload.tags
  end

  test "applies extracted business card fields and logo to the account" do
    @admin.update!(business_name: "Old name", address: "1 Old St")
    @media.update!(folder: folders(:business_card), extracted_info: {
      "status" => "done",
      "has_logo" => true,
      "fields" => { "business_name" => " Fade Co ", "phone" => "+1 555 0100", "website" => "https://fade.co", "address" => nil, "person_name" => "" }
    })
    @media.extracted_logo.attach(io: file_fixture("logo.png").open, filename: "logo.png", content_type: "image/png")

    patch apply_extraction_library_media_url(@media)

    assert_redirected_to library_item_url(@media, account: @admin.id)
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
    assert_redirected_to library_item_url(@media, account: @admin.id)
    assert_nil @media.reload.extracted_info

    @media.update!(folder: folders(:business_card))
    assert_enqueued_with(job: ExtractBusinessCardJob, args: [ @media.id ]) do
      post extract_library_media_url(@media)
    end
    assert_equal "pending", @media.reload.extraction_status
  end

  test "uploads photo files into the inbox by default" do
    user = sign_in_as(users(:lazaro_nixon))
    file = fixture_file_upload("logo.png", "image/png")

    assert_difference -> { user.library_media.count }, 1 do
      post library_media_index_url, params: { files: [ file ] }
    end

    media = user.library_media.order(:id).last
    assert media.file.attached?
    assert_equal [ "photo", folders(:inbox) ], [ media.kind, media.folder ]
    assert_redirected_to library_folders_url("inbox")
    assert_equal "Uploaded 1 file.", flash[:notice]
  end

  test "uploads into the folder it was dropped on and deletes back to it" do
    user = sign_in_as(users(:lazaro_nixon))

    post library_media_index_url, params: { folder_id: folders(:photobank_interior).id, files: [ fixture_file_upload("logo.png", "image/png") ] }
    media = user.library_media.order(:id).last
    assert_equal folders(:photobank_interior), media.folder
    assert_redirected_to library_folders_url("photobank", "interior")

    delete library_media_url(media)
    assert_redirected_to library_folders_url("photobank", "interior")
  end

  test "delete returns to the page it was clicked from" do
    delete library_media_url(@media), headers: { "HTTP_REFERER" => recipes_url }
    assert_redirected_to recipes_url
  end

  test "converts HEIC uploads to JPEG" do
    user = sign_in_as(users(:lazaro_nixon))

    post library_media_index_url, params: { files: [ fixture_file_upload("photo.heic", "application/octet-stream") ] }

    media = user.library_media.order(:id).last
    assert_equal "photo", media.kind
    assert_equal "image/jpeg", media.file.content_type
    assert_equal "photo.jpg", media.file.filename.to_s
  end

  test "upload dropped onto a group attaches to its source" do
    user = sign_in_as(users(:lazaro_nixon))
    source = user.library_media.create!(kind: "photo", folder: folders(:inbox))

    post library_media_index_url, params: { folder_id: folders(:photobank_interior).id, source_id: source.id, files: [ fixture_file_upload("logo.png", "image/png") ] }

    media = user.library_media.order(:id).last
    assert_equal source, media.original
    assert media.recipe_run.complete?
    assert_nil media.recipe_run.recipe
    assert_equal folders(:photobank_interior), media.folder
    assert_redirected_to library_folders_url("photobank", "interior")

    get library_item_url(media)
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

    assert_redirected_to library_folders_url("inbox")
    assert_equal "Drop a photo or video to upload.", flash[:alert]
  end
end
