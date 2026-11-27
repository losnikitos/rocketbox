# frozen_string_literal: true

require "test_helper"

class PresetTest < ActiveSupport::TestCase
  test "guide promo is a Preset subclass with guide-backed overlays" do
    preset = Preset.find("guide-promo")
    assert_kind_of Preset::GuidePromo, preset
    assert_equal Preset::SIZE, preset.size
    assert_includes preset.overlays.map(&:number), 10
    assert_equal "Keep the facade clear", preset.overlay_text(10)
  end

  test "guide promo scenes follow still → overlay → transition → … → cta" do
    media = bank_media!
    post = Post.create!(preset_slug: "guide-promo", source: media.id.to_s, rules: [ 10, 12 ], transition_type: "simple_fade")
    frame1 = attach_frame!(post, position: 1, rule_number: 10)
    frame2 = attach_frame!(post, position: 2, rule_number: 12)
    preset = post.preset
    scenes = preset.scenes_for(post)

    assert_equal %i[still overlay transition still overlay transition still cta], scenes.map(&:kind)
    assert_equal "v0", scenes.first.slug
    assert_equal "cta", scenes.last.slug
    assert_includes scenes.find { it.slug == "overlay-10" }.text, "#10"
    assert_equal "/guides/barbershop", scenes.last.href
    assert_equal frame1, scenes.find { it.slug == "v1" }.image
    assert_equal frame2, scenes.find { it.slug == "v2" }.image
  end

  test "source without frames still emits overlay → transition → empty still per rule" do
    media = bank_media!
    preset = Preset.find("guide-promo")
    post = Post.new(preset_slug: preset.slug, source: media.id.to_s, rules: [ 10, 12 ])
    scenes = preset.scenes_for(post)

    assert_equal %i[still overlay transition still overlay transition still cta], scenes.map(&:kind)
    assert_equal media, scenes.find { it.slug == "overlay-10" }.image
    assert_nil scenes.find { it.slug == "v1" }.image
    assert_nil scenes.find { it.slug == "overlay-12" }.image
    assert_nil scenes.find { it.slug == "v2" }.image
    assert_nil scenes.last.image
  end

  test "empty post is just source still then CTA" do
    preset = Preset.find("guide-promo")
    post = Post.new(preset.default_post_attrs)
    scenes = preset.scenes_for(post)

    assert_equal %i[still cta], scenes.map(&:kind)
    assert_nil scenes.first.image
  end

  test "bank media and post frame resolve to blob previews" do
    media = bank_media!
    assert_match %r{\Adata:image/png;base64,}, Preset.image_data_url(media)
    assert_match %r{/rails/active_storage/}, Preset.preview_url(media)

    post = Post.create!(preset_slug: "guide-promo", source: "", rules: [ 10 ], transition_type: "simple_fade")
    frame = attach_frame!(post, position: 1, rule_number: 10)
    assert_match %r{\Adata:image/png;base64,}, Preset.image_data_url(frame)
    assert_match %r{/rails/active_storage/}, Preset.preview_url(frame)
  end

  private

    def bank_media!
      media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, user: nil)
      media.file.attach(io: File.open(Rails.root.join("test/fixtures/files/logo.png")), filename: "logo.png", content_type: "image/png")
      media
    end

    def attach_frame!(post, position:, rule_number:)
      frame = post.frames.create!(position:, rule_number:)
      frame.file.attach(io: File.open(Rails.root.join("test/fixtures/files/logo.png")), filename: "frame.png", content_type: "image/png")
      frame
    end
end
