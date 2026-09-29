ActiveAdmin.register WorkflowStep do
  actions :index, :show

  index do
    id_column
    column :workflow_run
    column :key
    column :status
    column :started_at
    column :finished_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :workflow_run
      row :key
      row(:node) { it.definition&.node }
      row(:from) { it.definition&.from&.join(", ") }
      row(:params) { pre JSON.pretty_generate(it.definition&.params || {}), style: "white-space: pre-wrap" }
      row :status
      row :error
      row :started_at
      row :finished_at
      row :outputs do |step|
        ul do
          step.output_blobs.each do |blob|
            li link_to(blob.filename, rails_blob_path(blob, disposition: "attachment"))
          end
        end
      end
    end
  end
end
