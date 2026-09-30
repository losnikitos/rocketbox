# frozen_string_literal: true

require "test_helper"

class PromptTest < ActiveSupport::TestCase
  test "key must be a safe filename" do
    assert_not Prompt.new(key: "../x", body: "b").valid?
    assert Prompt.new(key: "new_prompt", body: "b").valid?
  end

  test "push upserts prompts/*.md" do
    Prompt.delete_all
    Prompt.push
    assert_equal Rails.root.glob("prompts/*.md").size, Prompt.count
    assert_equal Rails.root.join("prompts/crawl_business.md").read.strip, Prompt.body_for!(:crawl_business)
  end
end
