ActiveAdmin.register Workflow do
  actions :index, :show

  filter :name
  filter :created_at

  index do
    id_column
    column :name
    column("Nodes") { it.nodes.count }
    column("Edges") { it.edges.count }
    column("Runs") { it.runs.count }
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row(:edit) { link_to "Open in app", workflow_path(it) }
      row :created_at
      row :updated_at
    end

    panel "Nodes (workflow_nodes)" do
      table_for workflow.nodes.includes(:folder, :library_media, :tag, :transformation) do
        column :id
        column(:kind) { it.step? ? "Step" : it.library_media ? "Media" : "Folder" }
        column :label
        column(:folder) { auto_link(it.folder) if it.folder }
        column(:library_media) { auto_link(it.library_media) if it.library_media }
        column(:tag) { auto_link(it.tag) if it.tag }
        column(:transformation) { auto_link(it.transformation) if it.transformation }
        column :x
        column :y
      end
    end

    panel "Edges (workflow_edges)" do
      table_for workflow.edges.includes(:from, :to) do
        column :id
        column(:from) { "##{it.from_id} #{it.from.label}" }
        column(:to) { "##{it.to_id} #{it.to.label}" }
      end
    end

    panel "Runs (workflow_runs)" do
      table_for workflow.runs.includes(:step_runs) do
        column :id
        column :name
        column :error
        column(:step_runs) { |run| safe_join(run.step_runs.map { link_to "##{it.id} #{it.status}", admin_transformation_run_path(it) }, ", ") }
        column(:open) { |run| link_to "Open in app", workflow_path(workflow, run: run.id) }
        column :created_at
      end
    end
  end
end
