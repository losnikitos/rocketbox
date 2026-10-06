# frozen_string_literal: true

class AddSlugToRecipes < ActiveRecord::Migration[8.1]
  class Recipe < ActiveRecord::Base; end

  def up
    add_column :recipes, :slug, :string
    Recipe.reset_column_information
    Recipe.order(:id).find_each do |recipe|
      base = recipe.name.to_s.parameterize.presence || "recipe"
      base = "recipe-#{base}" if base.match?(/\A\d+\z/)
      slug = base
      slug = "#{base}-#{(2..).find { !Recipe.exists?(slug: "#{base}-#{it}") }}" if Recipe.exists?(slug:)
      recipe.update_columns(slug:)
    end
    change_column_null :recipes, :slug, false
    add_index :recipes, :slug, unique: true
  end

  def down
    remove_column :recipes, :slug
  end
end
