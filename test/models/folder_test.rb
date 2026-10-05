# frozen_string_literal: true

require "test_helper"

class FolderTest < ActiveSupport::TestCase
  test "subfolders sit one level below a root, with slugs unique per parent" do
    assert_not folders(:interior).children.new(name: "Deep").valid?
    assert_equal "team", folders(:inbox).children.create!(name: "Team").slug
    assert_equal "team", folders(:photobank).children.create!(name: "Team").slug
    assert_not_equal "team", folders(:inbox).children.create!(name: "Team").slug
  end

  test "top-level folders rename keeping their slug and delete only when empty" do
    assert folders(:inbox).update(name: "Mail")
    assert_equal folders(:inbox), Folder.inbox
    assert_not folders(:photobank).destroy_into_parent
    assert Folder.exists?(folders(:photobank).id)
    assert Folder.create!(name: "Clients").destroy_into_parent
  end

  test "media is a reserved slug" do
    assert_not Folder.new(name: "Media").valid?
  end
end
