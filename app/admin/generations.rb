ActiveAdmin.register Generation do
  actions :index, :show

  includes :prompt, :source_media, :generated_media

  index do
    id_column
    column :source_media
    column :prompt
    column :generated_media
    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :source_media
      row :prompt
      row :generated_media
      row :status
      row :error
      row :created_at
      row :updated_at
    end
  end
end
