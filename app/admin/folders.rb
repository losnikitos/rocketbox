ActiveAdmin.register Folder do
  permit_params :name, :parent_id, :color

  config.sort_order = "name_asc"

  index do
    selectable_column
    id_column
    column :name
    column :slug
    column :parent
    column :color
    column("Library media") { it.library_media.count }
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :parent, collection: Folder.roots.ordered
      f.input :color, as: :select, collection: Folder.colors.keys, include_blank: false
    end
    f.actions
  end
end
