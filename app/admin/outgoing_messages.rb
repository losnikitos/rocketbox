ActiveAdmin.register OutgoingMessage do
  menu parent: "Chats"
  actions :index, :show

  includes :user

  index do
    id_column
    column :channel
    column :kind
    column :recipient
    column :user
    column :body
    column :error
    column :created_at
    actions
  end
end
