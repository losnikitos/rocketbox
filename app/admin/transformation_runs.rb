ActiveAdmin.register TransformationRun do
  actions :index, :show

  includes :transformation, :workflow_run, :result

  index do
    id_column
    column :transformation
    column :workflow_run
    column :result
    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :transformation
      row :workflow_run
      row(:step) { |run| run.workflow_node && link_to(run.workflow_node.label, workflow_path(run.workflow_run.workflow, node: run.workflow_node_id, run: run.workflow_run_id)) }
      row(:inputs) { |run| safe_join(run.sources.map { auto_link(it) }, ", ") }
      row :result
      row :prompt_text
      row :status
      row :error
      row :created_at
      row :updated_at
    end
  end
end
