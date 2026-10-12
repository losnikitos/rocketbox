ActiveAdmin.register RubricPost do
  permit_params :library_media_id, :scheduled_at, :published_at, :error_message

  includes :rubric, :library_media

  filter :rubric
  filter :scheduled_at
  filter :published_at

  index do
    id_column
    column :rubric
    column :library_media
    column :scheduled_at
    column :published_at
    column :error_message
    actions
  end

  show do
    attributes_table do
      row :id
      row :rubric
      row(:open) { |post| link_to "Open in app", rubric_post_path(post.rubric, post, account: post.rubric.user_id) }
      row :library_media
      row :scheduled_at
      row :published_at
      row :error_message
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      f.input :library_media_id
      f.input :scheduled_at, as: :datetime_picker
      f.input :published_at, as: :datetime_picker
      f.input :error_message
    end
    f.actions
  end
end
