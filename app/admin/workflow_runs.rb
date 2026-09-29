ActiveAdmin.register WorkflowRun do
  actions :index, :show

  index do
    id_column
    column :smm_post
    column :workflow
    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :smm_post
      row :workflow
      row :status
      row :error
      row :created_at
      row :updated_at
    end

    panel "Steps" do
      table_for resource.workflow_steps.sort_by(&:id) do
        column(:key) { link_to it.key, admin_workflow_step_path(it) }
        column :status
        column :error
        column :started_at
        column :finished_at
      end
    end
  end
end
