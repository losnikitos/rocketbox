ActiveAdmin.register RubyLLM::ActiveRecord::Model, as: "Model" do
  menu parent: "RubyLLM"
  actions :index, :show
  config.sort_order = "position_asc"
  order_by(:position) { |clause| "#{clause.to_sql} NULLS LAST" }

  scope :enabled, default: true
  scope :all

  action_item :refresh, only: :index do
    link_to "Refresh models", refresh_admin_models_path, method: :post
  end

  collection_action :refresh, method: :post do
    RubyLLM::ActiveRecord::Model.refresh
    redirect_to admin_models_path, notice: "Models refreshed"
  rescue RubyLLM::ModelRegistryError => e
    redirect_to admin_models_path, alert: "Refresh failed: #{e.message}"
  end

  # Posted by the drag handles on the Enabled tab with every row's id, top to bottom.
  collection_action :sort, method: :post do
    Array(params[:ids]).each.with_index(1) { |id, position| RubyLLM::ActiveRecord::Model.where(id:).update_all(position:) }
    head :ok
  end

  batch_action :enable do |ids|
    RubyLLM::ActiveRecord::Model.where(id: ids).update_all(enabled: true)
    redirect_back_or_to admin_models_path, notice: "Models enabled"
  end

  batch_action :disable do |ids|
    RubyLLM::ActiveRecord::Model.where(id: ids).update_all(enabled: false)
    redirect_back_or_to admin_models_path, notice: "Models disabled"
  end

  filter :provider
  filter :family
  filter :model_id
  filter :name
  filter :enabled
  filter :unlisted_at

  index do
    selectable_column
    if current_scope&.id == "enabled"
      column("") { |model| span "☰", class: "handle", style: "cursor: move", data: { id: model.id, "sort-url": sort_admin_models_path } }
    end
    id_column
    column :provider
    column :model_id
    column :name
    column :enabled
    column :position
    column :context_window
    column :max_output_tokens
    column :unlisted_at
    actions
  end
end
