# frozen_string_literal: true

require "test_helper"

class GuideTest < ActiveSupport::TestCase
  test "access helpers and open? stay ungated" do
    guide = guides(:barbershop)

    assert guide.free?
    assert_not guide.members?
    assert_equal "Free", guide.access_label
    assert guide.open?

    guide.access = "members"
    assert guide.members?
    assert_equal "Members", guide.access_label
    assert guide.open?
  end

  test "rejects unknown access" do
    guide = guides(:barbershop)
    guide.access = "paid"

    assert_not guide.valid?
    assert_includes guide.errors[:access], "is not included in the list"
  end
end
