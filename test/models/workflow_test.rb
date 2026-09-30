# frozen_string_literal: true

require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  test "from: must name an earlier step" do
    error = assert_raises(ArgumentError) { Class.new(Workflow) { step :text, Workflow::TextOverlay, from: :photo } }
    assert_match(/unknown step photo/, error.message)
  end

  test "two photo story shape" do
    assert_equal "story", TwoPhotoStory.format
    assert_equal 2, TwoPhotoStory.input_count
    assert_equal [ %w[photo_1 photo_2], %w[film_1 film_2], %w[text_1 text_2], %w[story] ], TwoPhotoStory.columns.map { it.map(&:key) }
    assert_equal %w[film_1 text_1 story], TwoPhotoStory.downstream("film_1")
    assert_equal %w[text_1 text_2], TwoPhotoStory.text_steps.map(&:key)
    assert_nil ImagesToVideo.input_count
    assert_equal [ "post", 1 ], [ ImageToImage.format, ImageToImage.input_count ]
    assert_includes Workflow.all, TwoPhotoStory
  end
end
