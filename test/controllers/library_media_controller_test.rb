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

  test "owner deletes media and rubric posts made from it stay" do
    user = sign_in_as(users(:lazaro_nixon))
    media = user.library_media.create!(kind: "photo")
    media.file.attach(io: StringIO.new("img"), filename: "b.jpg", content_type: "image/jpeg")
    post = user.rubrics.create!(name: "Daily", schedule: "every day at 9am", folder: folders(:inbox)).posts.create!(library_media: media)

    assert_difference -> { LibraryMedia.count } => -1, -> { RubricPost.count } => 0 do
      delete library_media_url(media)
    end

    assert_redirected_to library_folders_url("inbox")
    assert_equal "Media deleted.", flash[:notice]
    assert_nil post.reload.library_media
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
    assert_response :no_content
    assert_equal [ tags(:before) ], @media.reload.tags.to_a

    get library_item_url(@media, account: @admin.id)
    assert_select "aside form[onchange*=requestSubmit] button[aria-label=Tags]"
    assert_select "aside button[aria-label=Tags] [data-pick-target=preview] > span > span", text: "before" do
      assert_select "svg.text-orange-500"
    end

    patch library_media_url(@media), params: { library_media: { tag_ids: [ "" ] } }
    assert_empty @media.reload.tags
  end

  test "sets and clears its job from the account's jobs" do
    job = @admin.jobs.create!
    get library_item_url(@media, account: @admin.id)
    assert_select "aside form[onchange*=requestSubmit] input[name='library_media[job_id]']"
    assert_select "aside [data-pick-target=option][value='#{job.id}']", text: /job_1\s+Job 1/

    patch library_media_url(@media), params: { library_media: { job_id: job.id } }
    assert_redirected_to library_item_url(@media, account: @admin.id)
    assert_equal "Moved to @job_1.", flash[:notice]
    assert_equal job, @media.reload.job

    patch library_media_url(@media), params: { library_media: { job_id: users(:lazaro_nixon).jobs.create!.id } }
    assert_equal "Job belongs to another account", flash[:alert]
    assert_equal job, @media.reload.job

    patch library_media_url(@media), params: { library_media: { job_id: "" } }
    assert_equal "Removed from job.", flash[:notice]
    assert_nil @media.reload.job
    assert_not Job.exists?(job.id), "a job left without media is deleted"

    get library_item_url(@media, account: @admin.id)
    assert_select "aside button[form=new-job]", text: "New job"
    post jobs_url, params: { library_media_id: @media.id }
    assert_redirected_to library_item_url(@media, account: @admin.id)
    assert_equal "Added to @job_1.", flash[:notice]
    assert_equal "Job 1", @media.reload.job.name
  end

  test "dragged onto another job or a new one, folding an emptied job's posts into it" do
    from, to = 2.times.map { @admin.jobs.create!(posts_count: 2) }
    other = LibraryMedia.create!(kind: "photo", user: @admin, job: from)
    @media.update!(job: from)

    patch library_media_url(@media), params: { library_media: { job_id: to.id } }, headers: { "Referer" => jobs_url }
    assert_redirected_to jobs_url
    assert_equal [ to, 2 ], [ @media.reload.job, from.reload.posts_count ]

    patch library_media_url(other), params: { library_media: { job_id: to.id } }
    assert_not Job.exists?(from.id)
    assert_equal 4, to.reload.posts_count

    assert_difference -> { @admin.jobs.count } do
      patch library_media_url(@media), params: { library_media: { job_id: "new" } }
    end
    assert_equal "Moved to @job_1.", flash[:notice]
    assert_equal [ "Job 1", 0 ], [ @media.reload.job.name, @media.job.posts_count ]
    assert_equal 4, to.reload.posts_count
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
    delete library_media_url(@media), headers: { "HTTP_REFERER" => workflows_url }
    assert_redirected_to workflows_url
  end

  test "delete from the media's own page goes to its folder" do
    delete library_media_url(@media), headers: { "HTTP_REFERER" => library_item_url(@media, account: @admin.id) }
    assert_redirected_to library_folders_url("inbox", account: @admin.id)
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
    assert media.transformation_run.complete?
    assert_nil media.transformation_run.transformation
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
