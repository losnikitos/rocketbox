# frozen_string_literal: true

require "test_helper"

class GuidesTest < ActionDispatch::IntegrationTest
  test "guides index lists published guides as covers and is linked from header and footer" do
    get guides_path

    assert_response :success
    assert_select "h1", text: "Guides"
    assert_select "a[href='#{guide_path(guides(:barbershop))}'] img[src='/guides/barbershop/clean.jpg']"
    assert_select "a[href='#{guide_path(guides(:barbershop))}']", text: /Barbershop/
    assert_select "a[href='#{guide_path(guides(:barbershop))}']", text: /Free/
    assert_select "nav[aria-label='Primary'] a[href='#{guides_path}']", text: "Guides"
    assert_select "nav[aria-label='Product'] a[href='#{guides_path}']", text: "Guides"
  end

  test "guide show is a promo page with cover, contents, and start reading" do
    guide = guides(:barbershop)
    first_chapter = guide_chapters(:visual_appeal)

    get guide_path(guide)

    assert_response :success
    assert_select "h1", text: "Barbershop"
    assert_select "img[src='/guides/barbershop/clean.jpg']"
    assert_select "*", text: /practical handbook/
    assert_select "a[href='#{guide_chapter_path(guide, first_chapter)}']", text: /Start reading/
    assert_select "#contents a[href='#{guide_chapter_path(guide, first_chapter)}']", text: /Visual appeal/
    assert_select "[data-guide-access='free']", text: /free to read/i
  end

  test "chapter show lists numbered rules and compare blocks" do
    chapter = guide_chapters(:visual_appeal)
    get guide_chapter_path(guides(:barbershop), chapter)

    assert_response :success
    assert_select "h1", text: "Visual appeal"
    assert_select "section#rule-10"
    assert_select "h2", text: "Keep the facade clear"
    assert_select "*", text: /Rule #10/
    assert_select "img[alt='Clear facade']"
    assert_select "img[alt='Sticker clutter']"
  end
end
