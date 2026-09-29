# frozen_string_literal: true

require "test_helper"

class TextOverlayTest < ActiveSupport::TestCase
  test "renders text inside the story safe area on a 1080x1920 canvas" do
    photo = Vips::Image.black(300, 400, bands: 3).add(90).cast(:uchar).jpegsave_buffer
    blank = Vips::Image.new_from_buffer(MediaCanvas.jpeg(MediaCanvas.cover(photo, "story")), "")
    out = Vips::Image.new_from_buffer(Workflow::TextOverlay.render(photo, { "body" => "Tap link below to book", "position" => "top_center", "style" => "none" }, "story"), "")

    assert_equal [ 1080, 1920 ], [ out.width, out.height ]
    top = MediaCanvas.insets("story").first
    text_band = ->(image) { image.crop(0, top, 1080, 200).avg }
    assert_operator text_band.(out), :>, text_band.(blank) + 5
    bottom = ->(image) { image.crop(0, 1600, 1080, 300).avg }
    assert_in_delta bottom.(blank), bottom.(out), 1
  end

  test "shade darkens the edge nearest the text" do
    photo = Vips::Image.black(300, 400, bands: 3).add(150).cast(:uchar).jpegsave_buffer
    %w[top bottom].each do |vertical|
      out = Vips::Image.new_from_buffer(Workflow::TextOverlay.render(photo, { "body" => "Hi", "position" => "#{vertical}_left" }, "story"), "")
      near, far = vertical == "top" ? [ 0, 1900 ] : [ 1900, 0 ]
      assert_operator out.crop(1000, near, 80, 20).avg, :<, 100, vertical
      assert_in_delta 150, out.crop(1000, far, 80, 20).avg, 3, vertical
    end
  end
end
