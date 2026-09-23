ActiveAdmin.register IncomingMessage do
  permit_params :channel, :external_id, :sender, :chat_id, :kind, :body, :payload, :user_id
end
