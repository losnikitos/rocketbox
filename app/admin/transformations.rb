ActiveAdmin.register Transformation do
  actions :index, :show

  includes :style, workflow_nodes: :workflow

  index do
    id_column
    column :name
    column :type_label
    column(:workflows) { safe_join(it.workflow_nodes.map { auto_link(it.workflow) }, ", ") }
    column :style
    column :shot_group
    column("Runs") { it.runs.count }
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :type_label
      row(:workflows) do
        safe_join(it.workflow_nodes.map { link_to it.workflow.name, workflow_path(it.workflow, node: it.id) }, ", ")
      end
      row :style
      row :shot_group
      row :body
      row(:layer_steps) { pre JSON.pretty_generate(it.layer_steps) }
      row(:options) { pre JSON.pretty_generate(it.options) }
      row :created_at
      row :updated_at
    end
  end
end
