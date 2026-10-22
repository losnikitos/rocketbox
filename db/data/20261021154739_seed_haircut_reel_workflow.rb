# frozen_string_literal: true

class SeedHaircutReelWorkflow < ActiveRecord::Migration[8.1]
  def up
    Workflow::InboxSort.ensure!
    Workflow::HaircutReel.ensure!
  end

  def down
    Workflow.find_by(slug: "haircut-reel")&.destroy!
  end
end
