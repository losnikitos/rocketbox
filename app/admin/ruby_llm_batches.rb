ActiveAdmin.register RubyLLM::ActiveRecord::Batch, as: "Batch" do
  menu parent: "RubyLLM"
  actions :index, :show

  filter :provider
  filter :status
  filter :completed
  filter :created_at

  index do
    selectable_column
    id_column
    column :provider
    column :provider_batch_id
    column :status
    column :completed
    column :created_at
    actions
  end
end
