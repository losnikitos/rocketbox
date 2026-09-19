# frozen_string_literal: true

require "test_helper"

class ListMediaTest < ActiveSupport::TestCase
  test "returns count and items for linked user" do
    user = users(:lazaro_nixon)
    TelegramUpload.create!(
      telegram_file_id: "f1",
      telegram_file_unique_id: "u1",
      chat_id: 1,
      from_id: 1,
      kind: "photo",
      user: user
    )
    TelegramUpload.create!(
      telegram_file_id: "f2",
      telegram_file_unique_id: "u2",
      chat_id: 1,
      from_id: 1,
      kind: "video",
      user: user
    )

    result = ListMedia.new(user:).execute

    assert_equal 2, result[:count]
    assert_equal 2, result[:items].size
    assert_equal %w[video photo], result[:items].map { |i| i[:kind] }
  end

  test "returns error when user is nil" do
    result = ListMedia.new(user: nil).execute

    assert result[:error].present?
    assert_match(/No Rocketbox account linked/, result[:error])
  end
end
