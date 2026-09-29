# frozen_string_literal: true

require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  test "from: must name an earlier step" do
    error = assert_raises(ArgumentError) { Class.new(Workflow) { step :text, Workflow::TextOverlay, from: :photo } }
    assert_match(/unknown step photo/, error.message)
  end

  test "bank holiday story shape" do
    assert_equal "story", BankHolidayStory.format
    assert_equal 2, BankHolidayStory.input_count
    assert_equal [ %w[photo_1 photo_2], %w[film_1 film_2], %w[text_1 text_2], %w[story] ], BankHolidayStory.columns.map { it.map(&:key) }
    assert_equal %w[film_1 text_1 story], BankHolidayStory.downstream("film_1")
    assert_nil CinematicShopReel.input_count
    assert_includes Workflow.all, BankHolidayStory
  end

  test "every prompt key has a prompts/ file" do
    Workflow.all.flat_map(&:steps).filter_map { it.params["prompt"] }.uniq.each do |key|
      assert Rails.root.join("prompts/#{key}.md").exist?, "missing prompts/#{key}.md"
    end
  end
end
