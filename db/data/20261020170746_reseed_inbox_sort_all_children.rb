# frozen_string_literal: true

class ReseedInboxSortAllChildren < ActiveRecord::Migration[8.1]
  def up
    Workflow::InboxSort.reset!
  end

  def down
    # Keeps the rewired graph; original six-folder layout isn't restored.
  end
end
