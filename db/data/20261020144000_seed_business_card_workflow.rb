# frozen_string_literal: true

class SeedBusinessCardWorkflow < ActiveRecord::Migration[8.1]
  def up
    Workflow::BusinessCard.ensure!
  end

  def down
    Workflow.find_by(slug: "business-card")&.destroy!
  end
end
