# frozen_string_literal: true

require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "ensure_defaults creates an empty guide promo post" do
    Post.delete_all
    Post.ensure_defaults!
    post = Post.find_by!(preset_slug: "guide-promo")
    assert_equal [], post.rules_list
    assert_equal "", post.source
    assert_empty post.frames
  end

  test "rejects unknown preset" do
    post = Post.new(preset_slug: "nope", source: "", rules: [])
    assert_not post.valid?
    assert_includes post.errors[:preset_slug], "is not a known preset"
  end

  test "changing source or rules wipes frames and renders" do
    post = Post.create!(preset_slug: "guide-promo", source: "", rules: [ 10 ], transition_type: "simple_fade")
    attach_frame!(post, position: 1, rule_number: 10)
    post.renders.create!(status: :done)
    assert_equal 1, post.frames.count
    assert_equal 1, post.renders.count

    post.update!(rules: [ 10, 12 ])
    assert_equal 0, post.frames.reload.count
    assert_equal 0, post.renders.reload.count

    attach_frame!(post, position: 1, rule_number: 10)
    post.renders.create!(status: :pending)
    media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, user: nil)
    post.update!(source: media.id.to_s)
    assert_equal 0, post.frames.reload.count
    assert_equal 0, post.renders.reload.count
  end

  test "changing transition wipes renders only" do
    post = Post.create!(preset_slug: "guide-promo", source: "", rules: [ 10 ], transition_type: "simple_fade")
    attach_frame!(post, position: 1, rule_number: 10)
    post.renders.create!(status: :done)
    assert_equal 1, post.frames.count

    # Only one transition is valid today — skip inclusion so the after_update path runs.
    post.transition_type = "cut"
    post.save!(validate: false)
    assert_equal 1, post.frames.reload.count
    assert_equal 0, post.renders.reload.count
  end

  test "source_media looks up the bank item by id" do
    media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, user: nil)
    post = Post.new(preset_slug: "guide-promo", source: media.id.to_s, rules: [])
    assert_equal media, post.source_media
    assert_nil Post.new(preset_slug: "guide-promo", source: "", rules: []).source_media
  end

  private

    def attach_frame!(post, position:, rule_number:)
      frame = post.frames.create!(position:, rule_number:)
      frame.file.attach(io: File.open(Rails.root.join("test/fixtures/files/logo.png")), filename: "frame.png", content_type: "image/png")
      frame
    end
end
