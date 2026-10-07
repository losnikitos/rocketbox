ActiveAdmin.register Recipe do
  actions :index, :show

  config.sort_order = "name_asc"

  includes :output_folder, :style, :recipe_folder

  index do
    id_column
    column :name
    column :type_label
    column :recipe_folder
    column :output_folder
    column("Runs") { it.runs.count }
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :slug
      row(:edit) { link_to "Open in app", recipe_path(it) }
      row :type_label
      row :recipe_folder
      row(:inputs) do
        safe_join(it.slots.map { |folder, tag, count| safe_join([ folder ? auto_link(folder) : "missing", (" #" if tag), (auto_link(tag) if tag), " ×#{count}" ]) }, ", ")
      end
      row :output_folder
      row(:output_tags) { safe_join(it.output_tags.map { auto_link(it) }, ", ") }
      row :style
      row :shot_group
      row :body
      row(:layer_steps) { pre JSON.pretty_generate(it.layer_steps) }
      row(:options) { pre JSON.pretty_generate(it.options) }
      row(:example) { image_tag it.example, class: "max-w-xs" if it.example.attached? }
      row :created_at
      row :updated_at
    end
  end
end
