# frozen_string_literal: true

require "test_helper"

class StoryboardTest < ActiveSupport::TestCase
  test "guide promo default scenes follow still → overlay → transition → … → cta" do
    board = Storyboard.find("guide-promo")
    settings = board.settings
    settings.assign_attributes(board.default_settings)
    scenes = board.send(:build_scenes, settings, video_index: 0)

    assert_equal %i[still overlay transition still overlay transition still cta], scenes.map(&:kind)
    assert_equal "v0", scenes.first.slug
    assert_equal "cta", scenes.last.slug
    assert_includes scenes.find { it.slug == "overlay-10" }.text, "#10"
    assert_equal "/guides/barbershop", scenes.last.href
  end

  test "video without afters stacks overlays on the source then CTA" do
    board = Storyboard.find("guide-promo")
    settings = StoryboardSetting.new(
      storyboard_slug: board.slug,
      transition_type: "simple_fade",
      cta_text: "Go",
      cta_href: "/guides/barbershop",
      overlays: [ { "number" => 10, "text" => "Keep the facade clear" }, { "number" => 12, "text" => "Use warm light" } ],
      videos: [ { "source" => "/guides/barbershop/cluttered.jpg", "rules" => [ 10, 12 ] } ]
    )
    scenes = board.send(:build_scenes, settings, video_index: 0)

    assert_equal %i[still overlay overlay cta], scenes.map(&:kind)
    assert scenes.select(&:overlay?).all? { it.image == "/guides/barbershop/cluttered.jpg" }
  end

  test "data_url embeds a public guide image" do
    url = Storyboard.data_url("/guides/barbershop/cluttered.jpg")
    assert_match %r{\Adata:image/jpeg;base64,}, url
  end

  test "media bank URL resolves through LibraryMedia.bank" do
    folder = Folder.bank
    media = LibraryMedia.create!(kind: "photo", folder:, user: nil)
    media.file.attach(io: File.open(Rails.root.join("test/fixtures/files/logo.png")), filename: "logo.png", content_type: "image/png")

    url = "/app/media_bank/#{media.id}"
    assert_equal media.id.to_s, Storyboard.media_bank_id(url)
    assert_match %r{\Adata:image/png;base64,}, Storyboard.image_data_url(url)
    assert_match %r{/rails/active_storage/}, Storyboard.preview_url(url)
  end
end
