ActiveAdmin.register Tag do
  permit_params :name

  config.sort_order = "name_asc"
  config.filters = false

  index do
    selectable_column
    id_column
    column :name
    column("Library media") { it.library_media.count }
    column("Workflows") do |tag|
      workflows = WorkflowNode.includes(:workflow).select { it.tag_ids.include?(tag.id) }.map(&:workflow).uniq.sort_by(&:name)
      safe_join(workflows.map { auto_link(it) }, ", ")
    end
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
    end
    f.actions
  end
end
