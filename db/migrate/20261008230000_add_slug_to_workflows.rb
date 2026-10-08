# frozen_string_literal: true

class AddSlugToWorkflows < ActiveRecord::Migration[8.1]
  class Workflow < ActiveRecord::Base; end

  def up
    add_column :workflows, :slug, :string
    Workflow.reset_column_information
    Workflow.order(:id).find_each do |workflow|
      base = workflow.name.to_s.parameterize.presence || "workflow"
      base = "workflow-#{base}" if base.match?(/\A\d+\z/)
      slug = base
      slug = "#{base}-#{(2..).find { !Workflow.exists?(slug: "#{base}-#{it}") }}" if Workflow.exists?(slug:)
      workflow.update_columns(slug:)
    end
    change_column_null :workflows, :slug, false
    add_index :workflows, :slug, unique: true
  end

  def down
    execute "DELETE FROM friendly_id_slugs WHERE sluggable_type = 'Workflow'"
    remove_column :workflows, :slug
  end
end
