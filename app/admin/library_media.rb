ActiveAdmin.register LibraryMedia do
  permit_params :kind, :user_id, :telegram_file_id, :telegram_file_unique_id,
                :chat_id, :from_id, :whatsapp_media_id, :whatsapp_from
end
