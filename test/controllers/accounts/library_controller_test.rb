# frozen_string_literal: true

require "test_helper"

class Accounts::LibraryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "media page shows details and a link back to its folder" do
    media = LibraryMedia.create!(kind: "photo", folder: folders(:interior), user: @user)
    media.file.attach(io: StringIO.new("img"), filename: "cut.jpg", content_type: "image/jpeg")

    get library_item_url(media)
    assert_response :success
    assert_select "h1", "Interior"
    assert_select "[aria-label='Folder tree'] a[href=?][aria-current=page]", library_folders_path("inbox", "interior")
    assert_select "main a[href=?]", library_folders_path("inbox", "interior"), text: %r{Inbox / Interior}
    assert_select "img[src]"
    assert_select "aside dd", text: "cut.jpg"
    assert_select "button", text: "Publish as Instagram story", count: 0
  end

  test "source shows recipes and generated media; generated links back to its source" do
    source = LibraryMedia.create!(kind: "photo", folder: folders(:interior), user: @user)
    source.file.attach(io: StringIO.new("img"), filename: "room.jpg", content_type: "image/jpeg")
    generated = LibraryMedia.create!(kind: "photo", folder: folders(:photobank_interior), user: @user)
    generated.file.attach(io: StringIO.new("img"), filename: "film.jpg", content_type: "image/jpeg")
    RecipeRun.create!(recipe: recipes(:cinematic), generated_media: generated, status: "complete", inputs: [ RecipeRunInput.new(library_media: source) ])
    failed = recipes(:cinematic).run!(media: [ source ])
    get library_item_url(failed.generated_media)
    assert_select "#recipe-run-heading + span", text: "running"
    failed.update!(status: "failed", error: "content policy")

    get library_item_url(source)
    assert_select "#apply_recipe a:not([data-turbo-frame])[href=?]", recipe_path(recipes(:cinematic), media_ids: { 0 => source.id }), text: /Cinematic shop reel/
    assert_select "a[href^=?]", recipe_path(recipes(:before_after)), count: 0
    assert_select "turbo-frame", count: 0
    assert_select "nav[aria-label=Versions] a", 3 do |links|
      assert_equal [ library_item_path(source), library_item_path(generated), library_item_path(failed.generated_media) ], links.map { it["href"] }
      assert_equal "page", links.first["aria-current"]
    end
    assert_select "nav[aria-label=Versions] a[href=?]", library_item_path(failed.generated_media), text: /Generation failed/
    assert_select "button[popovertarget=hero-media] img"

    get library_item_url(generated)
    assert_select "#recipe-run-heading + span", count: 0
    assert_select "label #compare-original"
    assert_select "button[popovertarget=hero-media][title='View full size']"
    assert_select "nav[aria-label=Versions] a[href=?]", library_item_path(source), text: /Original/
    assert_select "nav[aria-label=Versions] a[href=?][aria-current=page]", library_item_path(generated)
    assert_select "#recipe-run-heading", text: "Generation"
    assert_select "aside a[href=?]", library_item_path(source), count: 0

    get library_item_url(failed.generated_media)
    assert_select "details:has(#recipe-run-heading) p", text: "content policy"
    assert_select "details:has(#recipe-run-heading) a[href=?]", recipe_path(recipes(:cinematic)), text: /Cinematic shop reel/
    assert_select "details:has(#recipe-run-heading) tr", text: /Model\s*\S+/
  end

  test "show strips other media of the same folder" do
    room, hall, card = [ :interior, :interior, :business_card ].map do |folder|
      LibraryMedia.create!(kind: "photo", folder: folders(folder), user: @user)
    end
    curated = LibraryMedia.create!(kind: "photo", folder: folders(:photobank_interior), user: @user)

    get library_item_url(room)
    assert_select "nav[aria-label='Interior media']" do
      assert_select "a[href=?][aria-current=page]", library_item_path(room)
      assert_select "a[href=?]:not([aria-current])", library_item_path(hall)
      assert_select "a[href=?]", library_item_path(card), count: 0
      assert_select "a[href=?]", library_item_path(curated), count: 0
    end

    get library_item_url(card)
    assert_select "nav[aria-label='Business card media']", count: 0
  end

  test "ready media shows its recipe run; siblings come from the same recipe" do
    source = LibraryMedia.create!(kind: "photo", folder: folders(:photobank_interior), user: @user,
      file: { io: StringIO.new("img"), filename: "room.jpg", content_type: "image/jpeg" })
    recipe = Recipe.create!(name: "Collage", body: "Compose a collage.", inputs: [ { "folder_id" => folders(:photobank_interior).id } ])
    run = recipe.run!(media: [ source ])
    sibling = recipe.run!(media: [ source ])
    other = Recipe.create!(name: "Poster", body: "Make a poster.", inputs: [ { "folder_id" => folders(:photobank_interior).id } ]).run!(media: [ source ])

    run.update!(status: "failed", error: "content policy")
    get library_item_url(run.generated_media)
    assert_select "[aria-label='Folder tree'] a[href=?][aria-current=page]", library_folders_path("photobank", "ready")
    assert_select "#recipe-run-heading + span", text: "failed"
    assert_select "details:has(#recipe-run-heading) p", text: "content policy"
    assert_select "nav[aria-label='Collage media']" do
      assert_select "a[href=?]", library_item_path(sibling.generated_media)
      assert_select "a[href=?]", library_item_path(other.generated_media), count: 0
    end
  end

  test "cannot view another account's media" do
    media = LibraryMedia.create!(kind: "photo", user: users(:admin_user))

    get library_item_url(media)
    assert_response :not_found
  end

  test "requires sign in" do
    delete session_url(@user.sessions.last)
    get library_folders_url("inbox")
    assert_redirected_to sign_in_url
  end

  test "only admins see the admin link on media" do
    media = LibraryMedia.create!(kind: "photo", user: @user)
    get library_item_url(media)
    assert_select "[title='Admin actions']", count: 0

    admin = sign_in_as(users(:admin_user))
    media = LibraryMedia.create!(kind: "photo", user: admin)
    get library_item_url(media, account: admin.id)
    assert_select "a[href=?]", admin_library_media_path(media, account: admin.id), text: "Admin"
  end
end
