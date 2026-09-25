# frozen_string_literal: true

require "test_helper"

class MediaGenerationTest < ActiveSupport::TestCase
  test "valid with allowed image model" do
    generation = MediaGeneration.new(
      model: "grok-imagine-image-2.0",
      prompt: "a barber chair",
      user: users(:admin_user)
    )

    assert generation.valid?
    assert_equal "image", generation.media_type
    assert generation.in_progress?
  end

  test "infers video media_type from model" do
    generation = MediaGeneration.new(
      model: "grok-imagine-video-1.5",
      prompt: "clippers buzzing"
    )

    assert generation.valid?
    assert_equal "video", generation.media_type
  end

  test "rejects blank prompt" do
    generation = MediaGeneration.new(model: "grok-imagine-image-2.0", prompt: "")
    assert_not generation.valid?
    assert_includes generation.errors[:prompt], "can't be blank"
  end

  test "rejects unknown model" do
    generation = MediaGeneration.new(model: "not-a-real-model", prompt: "hi")
    assert_not generation.valid?
    assert generation.errors[:model].any?
  end
end
