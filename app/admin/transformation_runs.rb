ActiveAdmin.register TransformationRun do
  actions :index, :show

  includes :transformation, :workflow_run, :generated_media

  index do
    id_column
    column :transformation
    column :workflow_run
    column :generated_media
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
      row(:source_media) { |run| safe_join(run.source_media.map { auto_link(it) }, ", ") }
      row :generated_media
      row :prompt
      row :prompt_text
      row :status
      row :error
      row :created_at
      row :updated_at
    end
  end
end
