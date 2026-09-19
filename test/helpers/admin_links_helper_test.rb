# frozen_string_literal: true

require "test_helper"

class AdminLinksHelperTest < ActionView::TestCase
  test "admin_link_id_suffix is unique per call" do
    a = admin_link_id_suffix
    b = admin_link_id_suffix
    assert_match(/\A-[0-9a-f]{8}\z/, a)
    assert_match(/\A-[0-9a-f]{8}\z/, b)
    assert_not_equal a, b
  end
end
