ActiveAdmin.register Chat do
  menu parent: "RubyLLM"
  actions :index, :show

  filter :model
  filter :cancelled
  filter :created_at

  index do
    selectable_column
    id_column
    column :model
    column :cancelled
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :model
      row :cancelled
      row :created_at
      row :updated_at
    end

    panel "Messages" do
      table_for chat.messages do
        column(:id) { |message| link_to message.id, admin_message_path(message) }
        column :role
        column(:content) { |message| truncate(message.content.to_s, length: 200) }
        column :created_at
      end
    end
  end
end
