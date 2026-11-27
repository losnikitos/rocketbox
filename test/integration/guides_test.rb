# frozen_string_literal: true

require "test_helper"

class GuidesTest < ActionDispatch::IntegrationTest
  test "guides index lists published guides and is linked from header and footer" do
    get guides_path

    assert_response :success
    assert_select "h1", text: "Guides"
    assert_select "a[href='#{guide_path(guides(:barbershop))}']", text: /Barbershop/
    assert_select "nav[aria-label='Primary'] a[href='#{guides_path}']", text: "Guides"
    assert_select "nav[aria-label='Product'] a[href='#{guides_path}']", text: "Guides"
  end

  test "guide show lists chapters" do
    get guide_path(guides(:barbershop))

    assert_response :success
    assert_select "h1", text: "Barbershop"
    assert_select "a[href='#{guide_chapter_path(guides(:barbershop), guide_chapters(:visual_appeal))}']", text: /Visual appeal/
  end

  test "chapter show lists numbered rules and compare blocks" do
    chapter = guide_chapters(:visual_appeal)
    get guide_chapter_path(guides(:barbershop), chapter)

    assert_response :success
    assert_select "h1", text: "Visual appeal"
    assert_select "section#10"
    assert_select "h2", text: "Keep the facade clear"
    assert_select "*", text: /#10/
    assert_select "img[alt='Clear facade']"
    assert_select "img[alt='Sticker clutter']"
  end
end
