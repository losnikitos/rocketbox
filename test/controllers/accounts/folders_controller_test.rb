# frozen_string_literal: true

require "test_helper"

class Accounts::FoldersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "root shows the top-level folders with their whole tree's previews" do
    photo(folders(:interior))
    photo(folders(:inbox))

    get library_folders_url
    assert_response :success
    assert_select "h1", "Media"
    assert_select "a[href=?]", library_folders_path("inbox"), text: /Inbox/
    assert_select "a[href=?] [data-scrub-target=slide]", library_folders_path("inbox"), count: 2
    assert_select "a[href=?]", library_folders_path("photobank")
    assert_select "[aria-label='Folder tree'] a[href=?]", library_folders_path("inbox", "interior"), text: /Interior\s*1/
    assert_select "[aria-label='Folder tree'] a[href=?]", library_folders_path("inbox"), text: /Inbox\s*1/
    assert_select "[aria-label='Folder tree'] [aria-current=page]", count: 0
  end

  test "a top-level folder shows its subfolders and only its own media" do
    loose = photo(folders(:inbox))
    filed = photo(folders(:interior))
    curated = photo(folders(:photobank_interior))

    get library_folders_url("inbox")
    assert_response :success
    assert_select "h1", "Inbox"
    assert_select "ul[aria-label='Folders and files'] a[href=?]", library_folders_path("inbox", "interior"), text: /Interior/
    assert_select "ul[aria-label='Folders and files'] a[href=?] [data-scrub-target=slide]", library_folders_path("inbox", "interior"), count: 1
    assert_select "ul[aria-label='Folders and files'] #folder-media-#{loose.id}"
    assert_select "#folder-media-#{filed.id}", count: 0
    assert_select "#folder-media-#{curated.id}", count: 0
    assert_select "form[data-controller=drop-upload] input[name=folder_id][value=?]", folders(:inbox).id.to_s
    assert_select "label[for=library-upload-input]", text: /Upload/
    assert_select "button[popovertarget=new-folder]", count: 0
  end

  test "a subfolder shows its media and the workflows reading and writing it" do
    filed = photo(folders(:interior))
    loose = photo(folders(:inbox))
    reads = create_workflow("Cinematic", input: folders(:interior), transformation: transformations(:cinematic), output: folders(:photobank_interior))
    writes = create_workflow("Back in", input: folders(:misc), transformation: transformations(:before_after), output: folders(:interior))
    other = create_workflow("Other", input: folders(:misc), transformation: transformations(:before_after), output: folders(:photobank_misc))

    get library_folders_url("inbox", "interior")
    assert_response :success
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", library_folders_path("inbox"), text: "Inbox"
    assert_select "nav[aria-label=Breadcrumb] [aria-current=page]", text: "Interior"
    assert_select "[aria-label='Folder tree'] a[href=?][aria-current=page]", library_folders_path("inbox", "interior"), text: /Interior\s*1/
    assert_select "[aria-label='Folder tree'] a[href=?]", library_folders_path("photobank", "interior")
    assert_select "#folder-media-#{filed.id}"
    assert_select "#folder-media-#{loose.id}", count: 0
    assert_select "[id^=library-media-move-]", count: 0
    read_node = reads.nodes.find_by(folder: folders(:interior))
    write_node = writes.nodes.find_by(folder: folders(:interior))
    assert_select "section[aria-labelledby=folder-workflows-read] a[href=?]", workflow_path(reads, node: read_node.id), text: /Cinematic\s*Inbox \/ Interior/
    assert_select "section[aria-labelledby=folder-workflows-write] a[href=?]", workflow_path(writes, node: write_node.id), text: /Back in/
    assert_select "section[aria-labelledby=folder-workflows-read] a", count: 1
    assert_select "section[aria-labelledby=folder-workflows-write] a", count: 1
    assert_select "aside[aria-label=Workflows] a[href^=?]", workflow_path(other), count: 0
    assert_select "[id^=folder-rename-]", count: 0
  end

  test "ready lists the steps with no output folder as writing to it" do
    landed = create_workflow("No output", input: folders(:interior), transformation: transformations(:cinematic))
    filed = create_workflow("Filed", input: folders(:interior), transformation: transformations(:before_after), output: folders(:photobank_interior))

    get library_folders_url("photobank", "ready")
    assert_select "section[aria-labelledby=folder-workflows-write] a[href=?]", workflow_path(landed, node: landed.nodes.find(&:step?).id), text: /No output/
    assert_select "section[aria-labelledby=folder-workflows-write] a[href^=?]", workflow_path(filed), count: 0
    assert_select "section[aria-labelledby=folder-workflows-read] a", count: 0
  end

  test "admin creates, renames and deletes a subfolder; deleting moves its media up" do
    admin = sign_in_as(users(:admin_user))
    get library_folders_url("photobank", account: admin.id)
    assert_select "form#new-folder[action=?]", library_folders_path("photobank", account: admin.id)

    post library_folders_url("photobank"), params: { folder: { name: "Team" } }
    folder = folders(:photobank).children.find_by!(slug: "team")
    assert_redirected_to library_folders_url("photobank", "team", account: admin.id)
    media = photo(folder, user: admin)

    get library_folders_url("photobank", account: admin.id)
    assert_select "[id^=folder-admin-links-#{folder.id}-] a[href=?][data-turbo-method=delete]", library_folders_path("photobank", "team")

    get library_folders_url("photobank", "team", account: admin.id)
    assert_select "form[id^=folder-rename-#{folder.id}-] input[name='folder[name]'][value=Team]"
    assert_select "[id^=folder-admin-links-#{folder.id}-] a[href=?][data-turbo-method=delete]", library_folders_path("photobank", "team")
    assert_select "[id^=library-media-move-#{media.id}-] form[action^=?] button[disabled]", library_media_path(media), text: "Photobank / Team"
    assert_select "[id^=library-media-move-#{media.id}-] form[action^=?]", library_media_path(media), text: "Inbox / Interior"
    assert_select "#folder-media-#{media.id}[draggable=true][data-move-url^=?]", library_media_path(media)
    assert_select "[aria-label='Folder tree'] a[data-move-to=?]", folders(:interior).id.to_s
    assert_select "[aria-label='Folder tree'] a[data-move-to=?]", folder.id.to_s, count: 0

    patch library_folders_url("photobank", "team"), params: { folder: { name: "Crew" } }
    assert_equal [ "Crew", "team" ], folder.reload.values_at(:name, :slug)

    delete library_folders_url("photobank", "team")
    assert_redirected_to library_folders_url("photobank", account: admin.id)
    assert_not Folder.exists?(folder.id)
    assert_equal folders(:photobank), media.reload.folder
  end

  test "admin creates, renames and deletes a top-level folder" do
    admin = sign_in_as(users(:admin_user))
    get library_folders_url(account: admin.id)
    assert_select "form#new-folder[action=?]", library_folders_path(account: admin.id)

    post library_folders_url, params: { folder: { name: "Clients" } }
    folder = Folder.roots.find_by!(slug: "clients")
    assert_redirected_to library_folders_url("clients", account: admin.id)

    get library_folders_url("clients", account: admin.id)
    assert_select "form#new-folder[action=?]", library_folders_path("clients", account: admin.id)
    assert_select "form[id^=folder-rename-#{folder.id}-][action=?]", library_folders_path("clients", account: admin.id)

    patch library_folders_url("clients"), params: { folder: { name: "Customers" } }
    assert_equal [ "Customers", "clients" ], folder.reload.values_at(:name, :slug)

    delete library_folders_url("clients")
    assert_redirected_to library_folders_url(account: admin.id)
    assert_not Folder.exists?(folder.id)
  end

  test "admin recolors a folder; new subfolders take their parent's color" do
    admin = sign_in_as(users(:admin_user))
    get library_folders_url("inbox", account: admin.id)
    assert_select "[id^=folder-color-#{folders(:interior).id}-] form[action^=?] button[disabled]", library_folders_path("inbox", "interior"), text: /Emerald/

    patch library_folders_url("inbox", "interior"), params: { folder: { color: "rose" } }
    assert_equal "rose", folders(:interior).reload.color
    get library_folders_url("inbox", account: admin.id)
    assert_select "[aria-label='Folder tree'] a[href=?] svg.text-rose-400", library_folders_path("inbox", "interior")

    patch library_folders_url("inbox", "interior"), params: { folder: { color: "neon" } }
    assert_equal "rose", folders(:interior).reload.color

    post library_folders_url("inbox"), params: { folder: { name: "Team" } }
    assert_equal "emerald", folders(:inbox).children.find_by!(slug: "team").color
  end

  test "a folder that's a workflow's output can't be deleted" do
    admin = sign_in_as(users(:admin_user))
    create_workflow("Cinematic", input: folders(:interior), transformation: transformations(:cinematic), output: folders(:photobank_interior))

    delete library_folders_url("photobank", "interior")
    assert_redirected_to library_folders_url("photobank", "interior", account: admin.id)
    assert Folder.exists?(folders(:photobank_interior).id)
  end

  test "non-admins can't change folders" do
    assert_no_difference -> { Folder.count } do
      post library_folders_url("inbox"), params: { folder: { name: "Mine" } }
      delete library_folders_url("inbox", "interior")
    end
    patch library_folders_url("inbox", "interior"), params: { folder: { name: "Room" } }
    assert_equal "Interior", folders(:interior).reload.name
  end

  test "unknown folder is not found" do
    get "/app/library/nope"
    assert_response :not_found
    get "/app/library/inbox/nope"
    assert_response :not_found
  end

  private

    def photo(folder, user: @user)
      LibraryMedia.create!(kind: "photo", folder:, user:, file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    end
end
