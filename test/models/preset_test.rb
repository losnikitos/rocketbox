# frozen_string_literal: true

require "test_helper"

class PresetTest < ActiveSupport::TestCase
  test "guide promo default scenes follow still → overlay → transition → … → cta" do
    Post.delete_all
    Post.ensure_defaults!
    post = Post.find_by!(preset_slug: "guide-promo")
    preset = post.preset
    scenes = preset.scenes_for(post)

    assert_equal %i[still overlay transition still overlay transition still cta], scenes.map(&:kind)
    assert_equal "v0", scenes.first.slug
    assert_equal "cta", scenes.last.slug
    assert_includes scenes.find { it.slug == "overlay-10" }.text, "#10"
    assert_equal "/guides/barbershop", scenes.last.href
    assert_equal post.frames.first, scenes.find { it.slug == "v1" }.image
  end

  test "source without frames stacks overlays then CTA" do
    media = bank_media!
    preset = Preset.find("guide-promo")
    post = Post.new(preset_slug: preset.slug, source: media.id.to_s, rules: [ 10, 12 ])
    scenes = preset.scenes_for(post)

    assert_equal %i[still overlay overlay cta], scenes.map(&:kind)
    assert scenes.select(&:overlay?).all? { it.image == media }
  end

  test "bank media and post frame resolve to blob previews" do
    media = bank_media!
    assert_match %r{\Adata:image/png;base64,}, Preset.image_data_url(media)
    assert_match %r{/rails/active_storage/}, Preset.preview_url(media)

    Post.delete_all
    Post.ensure_defaults!
    frame = Post.find_by!(preset_slug: "guide-promo").frames.first
    assert_match %r{\Adata:image/jpeg;base64,}, Preset.image_data_url(frame)
    assert_match %r{/rails/active_storage/}, Preset.preview_url(frame)
  end

  private

    def bank_media!
      media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, user: nil)
      media.file.attach(io: File.open(Rails.root.join("test/fixtures/files/logo.png")), filename: "logo.png", content_type: "image/png")
      media
    end
end
