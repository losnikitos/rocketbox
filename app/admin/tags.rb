ActiveAdmin.register Tag do
  permit_params :name

  config.sort_order = "name_asc"
  config.filters = false

  index do
    selectable_column
    id_column
    column :name
    column("Library media") { it.library_media.count }
    column("Recipes") do |tag|
      recipes = Recipe.ordered.select { |recipe| recipe.output_tag_ids.include?(tag.id) || recipe.inputs.any? { it["tag_id"] == tag.id } }
      safe_join(recipes.map { auto_link(it) }, ", ")
    end
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
    end
    f.actions
  end
end
