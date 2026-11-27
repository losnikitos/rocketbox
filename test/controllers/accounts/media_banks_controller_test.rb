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

  test "show is a dedicated bookmarkable url" do
    get media_bank_url(@media, account: @admin.id)
    assert_response :success
    assert_select "aside", text: /media_bank\/#{@media.id}/
    assert_match media_bank_url(@media), response.body
  end

  test "upload create and destroy" do
    assert_difference -> { LibraryMedia.bank.count }, 1 do
      post media_banks_url(account: @admin.id), params: {
        files: [ fixture_file_upload("logo.png", "image/png") ],
        tag_ids: [ @shop.id ]
      }
    end
    created = LibraryMedia.bank.order(:id).last
      assert_redirected_to media_bank_path(created, account: @admin.id)

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
