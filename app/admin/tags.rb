ActiveAdmin.register Tag do
  permit_params :name

  config.sort_order = "name_asc"

  index do
    selectable_column
    id_column
    column :name
    column :slug
    column("Library media") { it.library_media.count }
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
    end
    f.actions
  end
end
