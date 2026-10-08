ActiveAdmin.register TransformationRun do
  actions :index, :show

  includes :transformation, :recipe, :generated_media

  index do
    id_column
    column :transformation
    column :recipe
    column :generated_media
    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :transformation
      row :recipe
      row(:source_media) { |run| safe_join(run.source_media.map { auto_link(it) }, ", ") }
      row :generated_media
      row :shot
      row :prompt
      row :status
      row :error
      row :created_at
      row :updated_at
    end
  end
end
