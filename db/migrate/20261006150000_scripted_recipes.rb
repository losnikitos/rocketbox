# frozen_string_literal: true

# Stitch and feature recipes become scripted ones; the effect fixes the layer and whether it takes a review.
class ScriptedRecipes < ActiveRecord::Migration[8.1]
  class Recipe < ActiveRecord::Base; end

  def up
    change_column_default :recipes, :effect, from: "default", to: nil
    change_column_null :recipes, :effect, true
    Recipe.reset_column_information
    Recipe.where(kind: "stitch").update_all(kind: "scripted")
    Recipe.where(kind: "scripted", effect: "default").update_all(effect: "steps")
    { "fully-booked" => "fully-booked", "fully-booked-color" => "fully-booked", "daily" => "daily", "review" => "review", "calendar" => "calendar" }
      .each { |layer, effect| Recipe.where(kind: "feature", layer_slug: layer).update_all(kind: "scripted", effect:) }
    Recipe.where.not(kind: "scripted").update_all(effect: nil)
    Recipe.where(effect: %w[steps doppler]).update_all(layer_steps: [])
    remove_column :recipes, :layer_slug
    remove_column :recipes, :takes_review
  end

  def down = raise(ActiveRecord::IrreversibleMigration)
end
