# frozen_string_literal: true

require "test_helper"

class PostRenderJobTest < ActiveJob::TestCase
  test "assembles an mp4 and attaches it" do
    Post.ensure_defaults!
    post = Post.find_by!(storyboard_slug: "guide-promo")
    render = post.renders.create!

    png = File.binread(Rails.root.join("test/fixtures/files/rendered.png"))
    Storyboard.singleton_class.alias_method :screenshot_original, :screenshot
    Storyboard.define_singleton_method(:screenshot) { |*| png }
    PostRenderJob.perform_now(render)
  ensure
    if Storyboard.respond_to?(:screenshot_original)
      Storyboard.singleton_class.alias_method :screenshot, :screenshot_original
      Storyboard.singleton_class.remove_method :screenshot_original
    end

    render.reload
    assert render.done?
    assert render.file.attached?
    assert_equal "video/mp4", render.file.content_type
  end
end
