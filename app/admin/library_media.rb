ActiveAdmin.register LibraryMedia do
  permit_params :kind, :folder_id, :user_id, :telegram_file_id, :telegram_file_unique_id,
                :chat_id, :from_id, :whatsapp_media_id, :whatsapp_from, tag_ids: []

  form do |f|
    f.inputs do
      f.input :user
      f.input :kind
      f.input :folder
      f.input :tags, as: :check_boxes, collection: Tag.ordered
      f.input :telegram_file_id
      f.input :telegram_file_unique_id
      f.input :chat_id
      f.input :from_id
      f.input :whatsapp_media_id
      f.input :whatsapp_from
    end
    f.actions
  end
end
