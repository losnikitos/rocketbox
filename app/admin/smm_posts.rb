ActiveAdmin.register SmmPost do
  permit_params :user_id, :prompt_id, :status, :caption, :error_message

  index do
    selectable_column
    id_column
    column :user
    column :prompt
    column :status
    column :published_at
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :user
      row :prompt
      row :status
      row :caption
      row :error_message
      row :generation_request_id
      row :published_at
      row :created_at
      row :updated_at
      row :generated_video do |post|
        if post.generated_video.attached?
          link_to post.generated_video.filename, rails_blob_path(post.generated_video, disposition: "attachment")
        end
      end
      row :library_media do |post|
        ul do
          post.library_media.each do |media|
            li link_to("LibraryMedia ##{media.id}", admin_library_media_path(media))
          end
        end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :user
      f.input :prompt
      f.input :status, as: :select, collection: SmmPost::STATUSES
      f.input :caption
      f.input :error_message
    end
    f.actions
  end
end
