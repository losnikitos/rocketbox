ActiveAdmin.register WorkflowRun do
  actions :index, :show, :edit, :update
  permit_params :name, :status, :error

  includes :workflow

  filter :workflow
  filter :name
  filter :status, as: :select, collection: WorkflowRun::STATUSES
  filter :created_at

  index do
    id_column
    column :workflow
    column :name
    column :status
    column :error
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :workflow
      row :name
      row :status
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

  form do |f|
    f.inputs do
      f.input :name
      f.input :status, as: :select, collection: WorkflowRun::STATUSES, include_blank: false
      f.input :error
    end
    f.actions
  end
end
