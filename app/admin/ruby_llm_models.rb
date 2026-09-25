ActiveAdmin.register RubyLLM::ActiveRecord::Model, as: "Model" do
  menu parent: "RubyLLM"
  actions :index, :show

  action_item :refresh, only: :index do
    link_to "Refresh models", refresh_admin_models_path, method: :post
  end

  collection_action :refresh, method: :post do
    RubyLLM::ActiveRecord::Model.refresh
    redirect_to admin_models_path, notice: "Models refreshed"
  rescue RubyLLM::ModelRegistryError => e
    redirect_to admin_models_path, alert: "Refresh failed: #{e.message}"
  end

  filter :provider
  filter :family
  filter :model_id
  filter :name
  filter :unlisted_at

  index do
    selectable_column
    id_column
    column :provider
    column :model_id
    column :name
    column :context_window
    column :max_output_tokens
    column :unlisted_at
    actions
  end
end
