# frozen_string_literal: true

class AddReadyRootFolder < ActiveRecord::Migration[8.1]
  class Folder < ActiveRecord::Base; end

  def up = Folder.find_or_create_by!(parent_id: nil, slug: "ready") { it.name, it.color = "Ready", "red" }

  def down = Folder.where(parent_id: nil, slug: "ready").delete_all
end
