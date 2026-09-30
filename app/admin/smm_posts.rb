ActiveAdmin.register SmmPost do
  permit_params :user_id, :format, :status, :caption, :error_message, :reaction, :reaction_comment

  index do
    selectable_column
    id_column
    column :user
    column :format
    column :status
    column :reaction
    column :published_at
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :user
      row :status
      row :reaction
      row :reaction_comment
      row :caption
      row :error_message
      row :format
      row :published_at
      row :created_at
      row :updated_at
      row :smm_slides do |post|
        ul do
          post.smm_slides.select { it.media.attached? }.each do |slide|
            li link_to(slide.media.filename, rails_blob_path(slide.media, disposition: "attachment"))
          end
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
      f.input :format, as: :select, collection: SmmPost.formats.keys
      f.input :status, as: :select, collection: SmmPost::STATUSES
      f.input :reaction, as: :select, collection: SmmPost::REACTIONS, include_blank: true
      f.input :reaction_comment
      f.input :caption
      f.input :error_message
    end
    f.actions
  end
end
