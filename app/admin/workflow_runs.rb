ActiveAdmin.register WorkflowRun do
  actions :index, :show

  includes :workflow

  filter :workflow
  filter :name
  filter :created_at

  index do
    id_column
    column :workflow
    column :name
    column :error
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :workflow
      row :name
      row(:open) { |run| link_to "Open in app", workflow_path(run.workflow, run: run.id) }
      row :picks
      row :error
      row :created_at
      row :updated_at
    end

    panel "Step runs (transformation_runs)" do
      table_for workflow_run.step_runs.includes(:transformation, :workflow_node, :generated_media) do
        column(:id) { link_to it.id, admin_transformation_run_path(it) }
        column(:node) { "##{it.workflow_node_id} #{it.workflow_node&.label}" }
        column :transformation
        column :generated_media
        column :status
        column :error
        column :created_at
      end
    end
  end
end
