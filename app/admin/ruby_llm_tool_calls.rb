ActiveAdmin.register RubyLLM::ActiveRecord::ToolCall, as: "ToolCall" do
  menu parent: "RubyLLM"
  actions :index, :show

  filter :name
  filter :approval
  filter :remote
  filter :created_at

  index do
    selectable_column
    id_column
    column :name
    column :tool_call_id
    column :approval
    column :remote
    column :created_at
    actions
  end
end
