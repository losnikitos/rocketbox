ActiveAdmin.register IncomingMessage do
  permit_params :channel, :external_id, :sender, :chat_id, :kind, :body, :payload, :user_id

  includes :user, attachments_attachments: :blob

  index do
    selectable_column
    id_column
    column :media do |message|
      div style: "display: flex; gap: 4px;" do
        message.attachments.each do |attachment|
          a href: url_for(attachment), target: "_blank", rel: "noopener" do
            if attachment.image?
              image_tag url_for(attachment), style: "height: 64px; width: 64px; object-fit: cover;"
            elsif attachment.video?
              video_tag url_for(attachment), muted: true, preload: "metadata", style: "height: 64px; width: 64px; object-fit: cover;"
            else
              text_node attachment.filename.to_s
            end
          end
        end
      end
    end
    column :channel
    column :kind
    column :sender
    column :user
    column :body
    column :created_at
    actions
  end

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
