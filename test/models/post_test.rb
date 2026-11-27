# frozen_string_literal: true

require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "ensure_defaults creates a guide promo post with demo frames" do
    Post.delete_all
    Post.ensure_defaults!
    post = Post.find_by!(preset_slug: "guide-promo")
    assert_equal [ 10, 12 ], post.rules_list
    assert_equal Preset::GUIDE_PROMO.default_source, post.source
    assert_equal [ 1, 2 ], post.frames.map(&:position)
    assert post.frames.all? { it.file.attached? }
  end

  test "rejects unknown preset" do
    post = Post.new(preset_slug: "nope", source: "/x.jpg", rules: [])
    assert_not post.valid?
    assert_includes post.errors[:preset_slug], "is not a known preset"
  end

  test "changing source or rules wipes frames and renders" do
    Post.delete_all
    Post.ensure_defaults!
    post = Post.find_by!(preset_slug: "guide-promo")
    post.renders.create!(status: :done)
    assert_equal 2, post.frames.count
    assert_equal 1, post.renders.count

    post.update!(rules: [ 10 ])
    assert_equal 0, post.frames.reload.count
    assert_equal 0, post.renders.reload.count

    post.seed_demo_frames!
    post.renders.create!(status: :pending)
    post.update!(source: "/guides/barbershop/warm.jpg")
    assert_equal 0, post.frames.reload.count
    assert_equal 0, post.renders.reload.count
  end
end
