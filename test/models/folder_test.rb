# frozen_string_literal: true

require "test_helper"

class FolderTest < ActiveSupport::TestCase
  test "subfolders sit one level below a root, with slugs unique per parent" do
    assert_not folders(:interior).children.new(name: "Deep").valid?
    assert_equal "team", folders(:inbox).children.create!(name: "Team").slug
    assert_equal "team", folders(:photobank).children.create!(name: "Team").slug
    assert_not_equal "team", folders(:inbox).children.create!(name: "Team").slug
  end

  test "roots can't be renamed or deleted" do
    assert_not folders(:inbox).update(name: "Mail")
    assert_not folders(:ready).destroy
    assert Folder.exists?(folders(:ready).id)
  end
end
