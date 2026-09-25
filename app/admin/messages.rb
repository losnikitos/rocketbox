ActiveAdmin.register Message do
  menu parent: "RubyLLM"
  actions :index, :show

  filter :chat
  filter :role
  filter :created_at

  index do
    selectable_column
    id_column
    column :chat
    column :role
    column(:content) { |message| truncate(message.content.to_s, length: 100) }
    column :created_at
    actions
  end
end
