# frozen_string_literal: true

class AddCoverPromoAndAccessToGuides < ActiveRecord::Migration[8.1]
  def change
    change_table :guides, bulk: true do |t|
      t.string :cover_image
      t.text :promo, null: false, default: ""
      t.string :access, null: false, default: "free"
    end
  end
end
