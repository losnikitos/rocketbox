# frozen_string_literal: true

class SeedBarbershopGuidePromoCover < ActiveRecord::Migration[8.1]
  def up
    guide = Guide.find_by(slug: "barbershop")
    return unless guide

    guide.update!(
      cover_image: "/guides/barbershop/clean.jpg",
      access: "free",
      promo: <<~TEXT
        A practical handbook for franchisees and shop owners who want the place to look sharp, book cleanly, and market without leaving the chair.

        Short chapters of numbered rules — facade, uniform, light, photos, booking, equipment, and the till. Compare blocks show the do and don’t side by side so the standard is obvious on the floor.
      TEXT
    )
  end

  def down
    Guide.find_by(slug: "barbershop")&.update!(cover_image: nil, promo: "", access: "free")
  end
end
