# frozen_string_literal: true

# Guide shell only — chapters and rules are seeded in ReseedBarbershopGuideRules.
class SeedBarbershopGuide < ActiveRecord::Migration[8.1]
  def up
    Guide.find_or_initialize_by(slug: "barbershop").update!(
      title: "Barbershop",
      lede: "The franchisee handbook — how the shop should look, run, book, market, and keep the books.",
      published: true
    )
  end

  def down
    Guide.find_by(slug: "barbershop")&.destroy!
  end
end
