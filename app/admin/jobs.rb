ActiveAdmin.register Job do
  permit_params :user_id, :name, :slug

  includes :user

  index do
    selectable_column
    id_column
    column :user
    column :name
    column(:slug) { "@#{it.slug}" }
    column("Library media") { it.library_media.count }
    column :created_at
    actions
  end

  filter :user
  filter :name
  filter :slug

  form do |f|
    f.inputs do
      f.input :user
      f.input :name
      f.input :slug, hint: "Set from the name when blank."
    end
    f.actions
  end
end
