# frozen_string_literal: true

require "test_helper"

class Accounts::TransformationRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @user = users(:lazaro_nixon)
    sign_in_as(@admin)
    @photo = @user.library_media.create!(kind: "photo", folder: folders(:interior),
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    @run = Transformation.create!(name: "Approval", kind: "approval").run!(items: [ @photo ], folder: folders(:ready))
  end

  test "approve completes a waiting run for the selected account" do
    post approve_transformation_run_url(@run, account: @user.id)
    assert_response :redirect
    assert_equal "complete", @run.reload.status
  end

  test "reject marks a waiting run rejected" do
    post reject_transformation_run_url(@run, account: @user.id)
    assert_response :redirect
    assert_equal "rejected", @run.reload.status
  end

  test "approve for another account's run is not found" do
    post approve_transformation_run_url(@run, account: @admin.id)
    assert_response :not_found
    assert_equal "waiting", @run.reload.status
  end
end
