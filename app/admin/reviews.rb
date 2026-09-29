ActiveAdmin.register Review do
  permit_params :user_id, :customer_name, :rating, :body, :archived_at, :avatar, media: []

  controller do
    # Blank file inputs would otherwise clear the existing attachments.
    before_action only: :update do
      attrs = params[:review]
      attrs.delete(:avatar) if attrs[:avatar].blank?
      attrs.delete(:media) if Array(attrs[:media]).compact_blank.empty?
    end
  end

  index do
    selectable_column
    id_column
    column :user
    column :customer_name
    column :rating
    column :archived_at
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :user
      row :customer_name
      row :rating
      row :body
      row :archived_at
      row :created_at
      row :updated_at
      row :avatar do |review|
        link_to review.avatar.filename, rails_blob_path(review.avatar, disposition: "attachment") if review.avatar.attached?
      end
      row :media do |review|
        ul do
          review.media.each do |file|
            li link_to(file.filename, rails_blob_path(file, disposition: "attachment"))
          end
        end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :user
      f.input :customer_name
      f.input :rating, as: :select, collection: 1..5
      f.input :body
      f.input :archived_at, as: :datetime_picker
      f.input :avatar, as: :file
      f.input :media, as: :file, input_html: { multiple: true }
    end
    f.actions
  end
end
