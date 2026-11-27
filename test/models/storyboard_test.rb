# frozen_string_literal: true

require "test_helper"

class StoryboardTest < ActiveSupport::TestCase
  test "guide promo scenes follow still → overlay → transition → … → cta" do
    board = Storyboard.find("guide-promo")
    assert_equal %i[still overlay transition still overlay transition still cta], board.scenes.map(&:kind)
    assert_equal "v0", board.scenes.first.slug
    assert_equal "cta", board.scenes.last.slug
    assert_includes board.find_scene("overlay-10").text, "#10"
    assert_equal "/guides/barbershop", board.find_scene("cta").href
  end

  test "data_url embeds a public guide image" do
    url = Storyboard.data_url("/guides/barbershop/cluttered.jpg")
    assert_match %r{\Adata:image/jpeg;base64,}, url
  end
end
