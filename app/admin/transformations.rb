ActiveAdmin.register Transformation do
  actions :index, :show

  includes :style, :recipes

  index do
    id_column
    column :type_label
    column(:recipes) { safe_join(it.recipes.map { auto_link(it) }, ", ") }
    column :style
    column :shot_group
    column("Runs") { it.runs.count }
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :type_label
      row(:recipes) { safe_join(it.recipes.map { auto_link(it) }, ", ") }
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
