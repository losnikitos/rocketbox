ActiveAdmin.register RecipeFolder do
  permit_params :name

  config.sort_order = "name_asc"

  index do
    selectable_column
    id_column
    column :name
    column :slug
    column("Recipes") { it.recipes.count }
    actions
  end
end
