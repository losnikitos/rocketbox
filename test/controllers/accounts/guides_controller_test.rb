# frozen_string_literal: true

require "test_helper"

class Accounts::GuidesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in_as(users(:admin_user))
    @guide = guides(:barbershop)
    @chapter = guide_chapters(:visual_appeal)
    @rule = guide_rules(:facade)
    @rule.update!(prompt: "Clear the facade glass.")
  end

  test "index lists guides under Studio" do
    get studio_guides_url(account: @admin.id)
    assert_response :success
    assert_select "a[href=?]", studio_guide_path(@guide, account: @admin.id), text: /Barbershop/
    assert_select "a[href=?][aria-selected=true]", studio_guides_path(account: @admin.id), text: /Guides/
  end

  test "guide chapter and rule have dedicated urls and show prompt" do
    get studio_guide_url(@guide, account: @admin.id)
    assert_response :success
    assert_select "a[href=?]", studio_guide_chapter_path(@guide, @chapter, account: @admin.id)

    get studio_guide_chapter_url(@guide, @chapter, account: @admin.id)
    assert_response :success
    assert_select "a[href=?]", studio_guide_chapter_rule_path(@guide, @chapter, @rule.number, account: @admin.id)
    assert_select "*", text: /Clear the facade glass/

    get studio_guide_chapter_rule_url(@guide, @chapter, @rule.number, account: @admin.id)
    assert_response :success
    assert_select "h2", text: @rule.title
    assert_select "*", text: /Clear the facade glass/
    assert_select "*", text: /Studio only/
  end

  test "non-admin is blocked" do
    sign_in_as(users(:lazaro_nixon))
    get studio_guides_url
    assert_redirected_to root_path
  end
end
