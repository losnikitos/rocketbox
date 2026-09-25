ActiveAdmin.register RubyLLM::ActiveRecord::Usage, as: "Usage" do
  menu parent: "RubyLLM"
  actions :index, :show

  filter :operation, as: :select, collection: %w[chat embedding moderation image speech transcription ocr rerank]
  filter :provider
  filter :model
  filter :status, as: :select, collection: %w[pending succeeded failed cancelled]
  filter :created_at

  index do
    selectable_column
    id_column
    column :operation
    column :provider
    column :model
    column :status
    column :input_tokens
    column :output_tokens
    column :total_cost
    column :created_at
    actions
  end
end
