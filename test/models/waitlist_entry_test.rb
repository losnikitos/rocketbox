# frozen_string_literal: true

require "test_helper"

class WaitlistEntryTest < ActiveSupport::TestCase
  test "requires business link email and phone" do
    entry = WaitlistEntry.new
    assert_not entry.valid?
    assert_includes entry.errors[:business_link], "can't be blank"
    assert_includes entry.errors[:email], "can't be blank"
    assert_includes entry.errors[:phone], "can't be blank"
  end

  test "normalizes email" do
    entry = WaitlistEntry.new(
      business_link: "https://example.com",
      email: "  Owner@Example.COM ",
      phone: "555"
    )
    assert entry.valid?
    assert_equal "owner@example.com", entry.email
  end
end
