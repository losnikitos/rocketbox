# frozen_string_literal: true

class SeedMediaBankFolder < ActiveRecord::Migration[8.1]
  def up
    Folder.roots.find_or_create_by!(slug: "bank") { it.assign_attributes(name: "Bank", color: "slate", kind: "media") }
    %w[barbershop storefront].each { |name| Tag.find_or_create_by!(name:) }
  end

  def down
    Folder.roots.find_by(slug: "bank")&.destroy
  end
end
