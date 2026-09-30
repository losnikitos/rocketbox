ActiveAdmin.register Generation do
  actions :index, :show

  includes :recipe, :workflow_run, :source_media, :generated_media

  index do
    id_column
    column :source_media
    column :recipe
    column :generated_media
    column(:status) { it.status }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :source_media
      row :recipe
      row :generated_media
      row :workflow_run
      row(:status) { it.status }
      row(:error) { it.error }
      row :created_at
      row :updated_at
    end

    if (run = resource.workflow_run)
      panel "Steps" do
        table_for run.workflow_steps.sort_by(&:id) do
          column(:key) { link_to it.key, admin_workflow_step_path(it) }
          column :status
          column :error
          column :started_at
          column :finished_at
        end
      end
    end
  end
end
