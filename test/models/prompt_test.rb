# frozen_string_literal: true

require "test_helper"

class PromptTest < ActiveSupport::TestCase
  test "requires name and body" do
    prompt = Prompt.new
    assert_not prompt.valid?
    assert_includes prompt.errors[:name], "can't be blank"
    assert_includes prompt.errors[:body], "can't be blank"
  end
end
