ActiveAdmin.register IncomingMessage do
  permit_params :channel, :external_id, :sender, :chat_id, :kind, :body, :payload, :user_id

  show do
    attributes_table do
      row :id
      row :channel
      row :external_id
      row :sender
      row :chat_id
      row :kind
      row :body
      row :user
      row :payload
      row :created_at
      row :updated_at
      row :attachments do |message|
        if message.attachments.attached?
          ul do
            message.attachments.each do |attachment|
              li do
                if attachment.image?
                  div { image_tag url_for(attachment), style: "max-width: 480px; height: auto;" }
                end
                span link_to(attachment.filename.to_s, url_for(attachment), target: "_blank", rel: "noopener")
              end
            end
          end
        else
          span "None"
        end
      end
    end
  end
end
