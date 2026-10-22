# frozen_string_literal: true

# Seeds the autorun workflow for the Meta review reel: two photos in inbox/haircuts become one reel,
# the owner taps Publish, and it goes to Instagram. Chat lines are this workflow's; other workflows stay quiet.
module Workflow::HaircutReel
  NAME = "Haircut reel"

  module_function

  def ensure!
    folder = Folder.inbox.children.find_or_create_by!(slug: "haircuts") { it.name = "Haircuts" }
    connect_sort!(folder)
    return Workflow.find_by(slug: NAME.parameterize) if Workflow.exists?(slug: NAME.parameterize)

    Workflow.create!(name: NAME, autorun: true).tap do |workflow|
      start = workflow.nodes.create!(folder:, x: 40, y: 80, take: 2, media_type: "image")
      collect = workflow.nodes.create!(x: 320, y: 80, transformation_attributes: { kind: "collect" })
      reel = workflow.nodes.create!(
        x: 600, y: 80,
        transformation_attributes: { kind: "gm_visuals", body: "We're preparing a reel" }
      )
      approval = workflow.nodes.create!(
        x: 880, y: 80,
        transformation_attributes: {
          kind: "approval",
          body: "Your reel is ready. Publish?",
          options: { "button" => "Publish" }
        }
      )
      publish = workflow.nodes.create!(
        x: 1160, y: 80,
        transformation_attributes: {
          kind: "publish",
          body: "Publishing to Instagram...",
          options: { "done" => "Your reel has been published", "button" => "View on Instagram" }
        }
      )
      [ start, collect, reel, approval, publish ].each_cons(2) { |from, to| workflow.edges.create!(from:, to:) }
    end
  end

  # Inbox sort only offers folders wired as outputs. Add Haircuts once, without resetting the sort workflow.
  def connect_sort!(folder)
    workflow = Workflow.find_by(slug: "inbox-sort") or return
    return if workflow.nodes.exists?(folder:)

    sort = workflow.nodes.joins(:transformation).find_by(transformations: { kind: "sort" }) or return
    node = workflow.nodes.create!(folder:, x: 680, y: workflow.nodes.maximum(:y).to_i + 72)
    workflow.edges.create!(from: sort, to: node)
  end
end
