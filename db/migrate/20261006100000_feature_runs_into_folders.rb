# frozen_string_literal: true

# Feature recipes run like the other kinds: their image lands in their output folder (photobank/stories), not a post.
class FeatureRunsIntoFolders < ActiveRecord::Migration[8.1]
  class Folder < ActiveRecord::Base; end
  class Recipe < ActiveRecord::Base; end

  def up
    add_reference :recipe_runs, :review, foreign_key: { on_delete: :nullify }
    if (photobank = Folder.find_by(parent_id: nil, slug: "photobank"))
      stories = Folder.find_or_create_by!(parent_id: photobank.id, slug: "stories") { it.name, it.color = "Stories", photobank.color }
      Recipe.where(kind: "feature").update_all(output_folder_id: stories.id)
    end
    ::SmmPost.where.not(recipe_id: nil).destroy_all
    remove_reference :smm_posts, :recipe, foreign_key: true, index: true
    remove_reference :smm_posts, :review, foreign_key: true, index: true
  end

  def down = raise(ActiveRecord::IrreversibleMigration)
end
