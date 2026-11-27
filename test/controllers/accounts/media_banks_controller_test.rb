# frozen_string_literal: true

require "test_helper"

class Accounts::MediaBanksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    @shop = Tag.find_or_create_by!(name: "01-demo-shop")
    @exterior = Tag.find_or_create_by!(name: "exterior")
    @media = LibraryMedia.create!(kind: "photo", folder: folders(:bank), tags: [ @shop, @exterior ])
    @media.file.attach(io: StringIO.new("fakejpg"), filename: "shop.jpg", content_type: "image/jpeg")
  end

  test "index groups by business and filters by tag" do
    get media_banks_url(account: @admin.id)
    assert_response :success
    assert_select "h2", text: /Demo Shop/
    assert_select "a[href=?]", media_bank_path(@media, account: @admin.id)
    assert_select "a[href=?]", media_banks_path(tag_id: @exterior.id, account: @admin.id), text: /#exterior/

    get media_banks_url(tag_id: @exterior.id, account: @admin.id)
    assert_response :success
    assert_select "a[href=?]", media_bank_path(@media, account: @admin.id)
  end

  test "show is a dedicated page with editable tags" do
    get media_bank_url(@media, account: @admin.id)
    assert_response :success
    assert_select "aside form[onchange*=requestSubmit] button[aria-label=Tags]"
    assert_select "p", text: /Copy this page URL/, count: 0
  end

  test "index hides the upload panel and keeps the header upload control" do
    get media_banks_url(account: @admin.id)
    assert_response :success
    assert_select "form.hidden[action=?]", media_banks_path(account: @admin.id)
    assert_select "label[for=media-bank-upload]", text: /Upload/
    assert_select "p", text: /Upload images/, count: 0
  end

  test "upload create, update tags, and destroy" do
    assert_difference -> { LibraryMedia.bank.count }, 1 do
      post media_banks_url(account: @admin.id), params: {
        files: [ fixture_file_upload("logo.png", "image/png") ]
      }
    end
    created = LibraryMedia.bank.order(:id).last
    assert_redirected_to media_bank_path(created, account: @admin.id)
    assert_empty created.tags

    patch media_bank_url(created, account: @admin.id),
          params: { library_media: { tag_ids: [ "", @shop.id, @exterior.id ] } }
    assert_response :no_content
    assert_equal [ @shop, @exterior ].sort_by(&:id), created.reload.tags.order(:id).to_a

    patch media_bank_url(created, account: @admin.id),
          params: { library_media: { tag_ids: [ "" ] } }
    assert_response :no_content
    assert_empty created.reload.tags

    assert_difference -> { LibraryMedia.bank.count }, -1 do
      delete media_bank_url(created, account: @admin.id)
    end
    assert_redirected_to media_banks_path(account: @admin.id)
  end

  test "studio nav points at media bank" do
    get media_banks_url(account: @admin.id)
    assert_select "a[href=?][aria-selected=true]", media_banks_path(account: @admin.id), text: /Media bank/
    assert_select "a[href=?]", posts_path(account: @admin.id)
  end

  test "non-admin is blocked" do
    sign_in_as(users(:lazaro_nixon))
    get media_banks_url
    assert_redirected_to root_path
  end
end
