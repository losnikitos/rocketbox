# frozen_string_literal: true

# Seeds the autorun workflow that files Inbox-root media into Inbox subfolders (vision Sort step).
# Outputs are every current Inbox child; admins can disconnect any they don't want filled automatically.
# Sort only offers folders still connected as outputs.
module Workflow::InboxSort
  NAME = "Inbox sort"

  module_function

  def ensure!
    Workflow.find_by(slug: NAME.parameterize) || build!
  end

  # Wipe nodes/edges/runs and rewire from every Inbox child (keeps the workflow row and slug).
  def reset!
    if (workflow = Workflow.find_by(slug: NAME.parameterize))
      workflow.runs.destroy_all
      workflow.edges.delete_all
      workflow.nodes.destroy_all
      wire!(workflow)
      workflow
    else
      build!
    end
  end

  def build!
    Workflow.create!(name: NAME, autorun: true).tap { wire!(it) }
  end
  private_class_method :build!

  def wire!(workflow)
    inbox = workflow.nodes.create!(folder: Folder.inbox, x: 40, y: 200, include_subfolders: false)
    sort = workflow.nodes.create!(
      x: 360, y: 200,
      transformation_attributes: { kind: "sort", body: Transformation::Sort::DEFAULT_BODY }
    )
    workflow.edges.create!(from: inbox, to: sort)

    Folder.inbox.children.ordered.each_with_index do |folder, i|
      node = workflow.nodes.create!(folder:, x: 680, y: 40 + i * 72)
      workflow.edges.create!(from: sort, to: node)
    end
  end
  private_class_method :wire!
end
