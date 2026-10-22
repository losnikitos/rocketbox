# frozen_string_literal: true

class SeedInboxSortWorkflow < ActiveRecord::Migration[8.1]
  def up
    Workflow::InboxSort.ensure!
  end

  def down
    Workflow.find_by(slug: "inbox-sort")&.destroy!
  end
end
