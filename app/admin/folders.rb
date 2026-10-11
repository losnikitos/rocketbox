ActiveAdmin.register Folder do
  permit_params :name, :parent_id, :color, :kind

  config.sort_order = "name_asc"

  index do
    selectable_column
    id_column
    column :name
    column :slug
    column :parent
    column :color
    column :kind
    column("Items") { it.items.count }
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :parent, collection: Folder.roots.ordered
      f.input :color, as: :select, collection: Folder.colors.keys, include_blank: false
      f.input :kind, as: :select, collection: Folder.kinds.keys, include_blank: false, hint: "A subfolder takes its parent's."
    end
    f.actions
  end
end
