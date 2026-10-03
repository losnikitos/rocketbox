ActiveAdmin.register RubyLLM::ActiveRecord::Usage, as: "Usage" do
  menu parent: "RubyLLM"
  actions :index, :show

  filter :operation, as: :select, collection: %w[chat embedding moderation image speech transcription ocr rerank]
  filter :provider
  filter :model
  filter :status, as: :select, collection: %w[pending succeeded failed cancelled]
  filter :created_at

  usd = { precision: 6, strip_insignificant_zeros: true }

  index do
    selectable_column
    id_column
    column :operation
    column :provider
    column :model
    column :status
    column :input_tokens
    column :output_tokens
    column(:total_cost) { |usage| number_to_currency(usage.total_cost, **usd) }
    column :created_at
    actions
  end

  show do
    attributes_table do
      active_admin_config.resource_columns.each do |attr|
        attr.end_with?("_cost") ? row(attr) { |usage| number_to_currency(usage.public_send(attr), **usd) } : row(attr)
      end
    end
  end
end
