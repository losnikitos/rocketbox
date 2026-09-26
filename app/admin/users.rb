ActiveAdmin.register User do
  permit_params :email, :name, :business_name, :role, :verified, :instagram_user_id, :instagram_access_token,
                :telegram_user_id, :whatsapp_phone

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :business_name
    column :role
    column :verified
    column :created_at
    actions
  end

  filter :email
  filter :role, as: :select, collection: User::ROLES
  filter :verified
  filter :created_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :name
      f.input :business_name
      f.input :role, as: :select, collection: User::ROLES
      f.input :verified
      f.input :instagram_user_id
      f.input :instagram_access_token
      f.input :telegram_user_id
      f.input :whatsapp_phone
    end
    f.actions
  end
end
