# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "upload_day_label buckets" do
    travel_to Time.zone.local(2026, 9, 26, 12) do # Saturday
      assert_equal "Today", upload_day_label(Date.new(2026, 9, 26))
      assert_equal "Yesterday", upload_day_label(Date.new(2026, 9, 25))
      assert_equal "Thursday", upload_day_label(Date.new(2026, 9, 24))
      assert_equal "Monday", upload_day_label(Date.new(2026, 9, 21))
      assert_equal "Sun 20 Sep", upload_day_label(Date.new(2026, 9, 20))
      assert_equal "Fri 26 Dec 2025", upload_day_label(Date.new(2025, 12, 26))
    end
  end

  test "render_markdown keeps tables and strips scripts" do
    html = render_markdown("| a |\n| --- |\n| 1 |\n\n<script>alert(1)</script>")
    assert_includes html, "<td>1</td>"
    assert_not_includes html, "<script"
  end
end
