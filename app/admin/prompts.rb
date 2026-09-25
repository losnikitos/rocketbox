ActiveAdmin.register Prompt do
  permit_params :name, :body, :active, :position

  index do
    selectable_column
    id_column
    column :name
    column :active
    column :position
    column :created_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :body
      f.input :active
      f.input :position
    end
    f.actions
  end
end
