# frozen_string_literal: true

# Seeds the autorun workflow that reads inbox business-card / logo photos into photobank/logo + User fields.
module Workflow::BusinessCard
  NAME = "Business card"

  module_function

  def ensure!
    return Workflow.find_by(slug: NAME.parameterize) if Workflow.exists?(slug: NAME.parameterize)

    card_folder = Folder.inbox.children.find_or_create_by!(slug: "business-card") { it.name = "Business card" }
    logo_in_folder = Folder.inbox.children.find_or_create_by!(slug: "logo") { it.name = "Logo" }
    Folder.photobank.children.find_or_create_by!(slug: "logo") { it.name = "Logo" }

    Workflow.create!(name: NAME, autorun: true).tap do |workflow|
      card = workflow.nodes.create!(folder: card_folder, x: 40, y: 40)
      logo_in = workflow.nodes.create!(folder: logo_in_folder, x: 40, y: 220)
      extract = workflow.nodes.create!(
        x: 360, y: 40,
        transformation_attributes: { kind: "extract_logo", body: Transformation::ExtractLogo::DEFAULT_BODY }
      )
      update = workflow.nodes.create!(
        x: 360, y: 220,
        transformation_attributes: { kind: "update_business", body: Transformation::UpdateBusiness::DEFAULT_BODY }
      )
      logo_out = workflow.nodes.create!(folder: Folder.logo, x: 680, y: 40)

      [ card, logo_in ].each do |start|
        workflow.edges.create!(from: start, to: extract)
        workflow.edges.create!(from: start, to: update)
      end
      workflow.edges.create!(from: extract, to: logo_out)
    end
  end
end
