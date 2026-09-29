ActiveAdmin.register Prompt do
  permit_params :key, :body

  index do
    selectable_column
    id_column
    column :key
    column :updated_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :key
      f.input :body
    end
    f.actions
  end
end
