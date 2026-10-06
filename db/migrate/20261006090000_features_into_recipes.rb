# frozen_string_literal: true

# Recipe inputs gain a fixed style, a review and a fixed layer; the code-defined features become feature recipes.
class FeaturesIntoRecipes < ActiveRecord::Migration[8.1]
  class Folder < ActiveRecord::Base; end
  class Recipe < ActiveRecord::Base; end
  class RecipeRun < ActiveRecord::Base; end
  class LibraryMedia < ActiveRecord::Base
    self.table_name = "library_media"
  end
  class SmmPost < ActiveRecord::Base; end

  def up
    add_reference :recipes, :style, foreign_key: { on_delete: :nullify }
    add_column :recipes, :layer_slug, :string
    add_column :recipes, :takes_review, :boolean, default: false, null: false
    remove_column :recipes, :takes_style
    add_reference :smm_posts, :recipe, foreign_key: { on_delete: :nullify }
    [ Recipe, SmmPost ].each(&:reset_column_information)
    move_features
    remove_column :smm_posts, :feature_slug
    drop_table :feature_settings
  end

  def down = raise(ActiveRecord::IrreversibleMigration)

  private

    def move_features
      photobank = Folder.find_by(parent_id: nil, slug: "photobank") or return
      ready = Folder.find_by!(parent_id: photobank.id, slug: "ready")
      # Daily took Ready photos made by recipe 8; those move into their own folder.
      daily = ready
      if (budni = Recipe.find_by(id: 8))
        daily = Folder.find_or_create_by!(parent_id: photobank.id, slug: "daily") { it.name, it.color = "Daily", photobank.color }
        LibraryMedia.where(id: RecipeRun.where(recipe_id: budni.id).select(:generated_media_id), folder_id: budni.output_folder_id)
          .update_all(folder_id: daily.id)
        budni.update_columns(output_folder_id: daily.id)
      end
      {
        "fully-booked" => [ "Fully booked", ready, "fully-booked", false ],
        "reviews" => [ "Reviews", ready, "review", true ],
        "daily" => [ "Daily", daily, "daily", false ]
      }.each do |slug, (name, folder, layer_slug, takes_review)|
        recipe = Recipe.create!(name:, kind: "feature", group: "Features", body: "", inputs: [ { "folder_id" => folder.id } ],
          layer_slug:, takes_review:, output_folder_id: ready.id)
        SmmPost.where(feature_slug: slug).update_all(recipe_id: recipe.id)
      end
    end
end
