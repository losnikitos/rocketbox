# frozen_string_literal: true

require "test_helper"

class FeaturesControllerTest < ActionDispatch::IntegrationTest
  setup { @admin = sign_in_as(users(:admin_user)) }

  test "index links to each feature, whose show page holds the settings" do
    get features_url(account: @admin.id)
    assert_select "a[href=?]", feature_path("fully-booked", account: @admin.id), text: /Off/

    get feature_url("fully-booked", account: @admin.id)
    assert_select "input[type=checkbox][name=?]", "feature_setting[enabled]"
    assert_select "select[name=?]", "feature_setting[layer_slug]"
    assert_select "button[disabled]", text: /Compose draft now/

    patch feature_url("fully-booked", account: @admin.id), params: { feature_setting: { enabled: "1" } }
    assert_redirected_to feature_url("fully-booked", account: @admin.id)

    get features_url(account: @admin.id)
    assert_select "a[href=?]", feature_path("fully-booked", account: @admin.id), text: /On/
  end
end
