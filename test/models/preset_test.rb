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
    assert_match %r{\Apost_frame/\d+\z}, scenes.find { it.slug == "v1" }.image
  end

  test "source without frames stacks overlays then CTA" do
    preset = Preset.find("guide-promo")
    post = Post.new(
      preset_slug: preset.slug,
      source: "/guides/barbershop/warm.jpg",
      rules: [ 10, 12 ]
    )
    scenes = preset.scenes_for(post)

    assert_equal %i[still overlay overlay cta], scenes.map(&:kind)
    assert scenes.select(&:overlay?).all? { it.image == "/guides/barbershop/warm.jpg" }
  end

  test "data_url embeds a public guide image" do
    url = Preset.data_url("/guides/barbershop/cluttered.jpg")
    assert_match %r{\Adata:image/jpeg;base64,}, url
  end

  test "media bank URL resolves through LibraryMedia.bank" do
    folder = Folder.bank
    media = LibraryMedia.create!(kind: "photo", folder:, user: nil)
    media.file.attach(io: File.open(Rails.root.join("test/fixtures/files/logo.png")), filename: "logo.png", content_type: "image/png")

    url = "/app/media_bank/#{media.id}"
    assert_equal media.id.to_s, Preset.media_bank_id(url)
    assert_match %r{\Adata:image/png;base64,}, Preset.image_data_url(url)
    assert_match %r{/rails/active_storage/}, Preset.preview_url(url)
  end

  test "post_frame ref resolves through PostFrame attachment" do
    Post.delete_all
    Post.ensure_defaults!
    frame = Post.find_by!(preset_slug: "guide-promo").frames.first
    ref = frame.source_ref

    assert_equal frame.id.to_s, Preset.post_frame_id(ref)
    assert_match %r{\Adata:image/jpeg;base64,}, Preset.image_data_url(ref)
    assert_match %r{/rails/active_storage/}, Preset.preview_url(ref)
  end
end
