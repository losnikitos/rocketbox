# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Folder::ROOTS.each { |slug| Folder.roots.find_or_create_by!(slug:) { it.name = slug.humanize } }
[ Folder.inbox, Folder.photobank ].each do |root|
  %w[business_card interior exterior logo customer misc].each do |key|
    root.children.find_or_create_by!(slug: key.dasherize) { it.name = key.humanize }
  end
end
Folder.photobank.children.find_or_create_by!(slug: "ready") { it.name = "Ready" }

# Meta app review account (credentials are shared with the submission).
User.find_or_initialize_by(email: "review@meta.com").update!(password: "review_2026", verified: true)
