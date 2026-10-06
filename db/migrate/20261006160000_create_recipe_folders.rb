# frozen_string_literal: true

# A recipe's free-text group becomes a folder with a slug.
class CreateRecipeFolders < ActiveRecord::Migration[8.1]
  class Recipe < ActiveRecord::Base; end
  class RecipeFolder < ActiveRecord::Base; end

  def up
    create_table :recipe_folders do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
      t.index :slug, unique: true
    end
    add_reference :recipes, :recipe_folder, foreign_key: true
    Recipe.reset_column_information
    Recipe.where.not(group: nil).distinct.order(:group).pluck(:group).each do |name|
      base = name.parameterize.presence || "folder"
      slug = base
      slug = "#{base}-#{(2..).find { !RecipeFolder.exists?(slug: "#{base}-#{it}") }}" if RecipeFolder.exists?(slug:)
      Recipe.where(group: name).update_all(recipe_folder_id: RecipeFolder.create!(name:, slug:).id)
    end
    remove_column :recipes, :group
  end

  def down = raise(ActiveRecord::IrreversibleMigration)
end
