# frozen_string_literal: true

require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "ensure_defaults creates a guide promo post" do
    Post.delete_all
    Post.ensure_defaults!
    post = Post.find_by!(storyboard_slug: "guide-promo")
    assert_equal "Guide promo", post.name
    assert_equal [ 10, 12 ], post.rules_list
    assert_equal Storyboard::GUIDE_PROMO.default_source, post.source
  end

  test "rejects unknown storyboard" do
    post = Post.new(name: "x", storyboard_slug: "nope", source: "/x.jpg", rules: [])
    assert_not post.valid?
    assert_includes post.errors[:storyboard_slug], "is not a known storyboard"
  end
end
