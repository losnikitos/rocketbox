# frozen_string_literal: true

require "test_helper"

class StoryboardRenderJobTest < ActiveJob::TestCase
  test "assembles an mp4 and attaches it" do
    board = Storyboard.find("guide-promo")
    StoryboardSetting.for(board).tap { it.assign_attributes(board.default_settings) }.save!
    render = StoryboardRender.create!(storyboard_slug: board.slug, video_index: 0)

    png = File.binread(Rails.root.join("test/fixtures/files/rendered.png"))
    Storyboard.singleton_class.alias_method :screenshot_original, :screenshot
    Storyboard.define_singleton_method(:screenshot) { |*| png }
    StoryboardRenderJob.perform_now(render)
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
