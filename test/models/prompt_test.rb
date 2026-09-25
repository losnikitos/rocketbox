# frozen_string_literal: true

require "test_helper"

class PromptTest < ActiveSupport::TestCase
  test "library returns active prompts ordered by position" do
    names = Prompt.library.pluck(:name)
    assert_equal [ "Cinematic shop reel", "Before → after energy" ], names
    assert_not_includes names, "Inactive prompt"
  end

  test "requires name and body" do
    prompt = Prompt.new
    assert_not prompt.valid?
    assert_includes prompt.errors[:name], "can't be blank"
    assert_includes prompt.errors[:body], "can't be blank"
  end
end
