ActiveAdmin.register Prompt do
  permit_params :name, :key, :body, :active, :position

  index do
    selectable_column
    id_column
    column :name
    column :key
    column :active
    column :position
    column :created_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :key, hint: "System prompts only (e.g. business_card_info). Keyed prompts are hidden from the post prompt picker."
      f.input :body
      f.input :active
      f.input :position
    end
    f.actions
  end
end
